# frozen_string_literal: true
class Tasks::StacksIngest::Backlog::Utilities::FileAttachmentService < Tasks::IngestHelperUtils::BaseFileAttachmentService
  SLEEP_INTERVAL = 0.5
  
  def initialize(config:, tracker:, log_file_path:, metadata_ingest_result_path:)
    super(config: config, tracker: tracker, log_file_path: log_file_path, metadata_ingest_result_path: metadata_ingest_result_path)
    @existing_ids = load_seen_attachment_ids
    @full_text_path = config['full_text_dir']
    @input_csv_path = config['input_csv_path']
    @csv_rows = load_csv_rows
  end

  def process_record(record)
    cdc_id = record.dig('ids', 'cdc_id')
    work_id = record.dig('ids', 'work_id')
    work = Article.find(work_id)
    depositor = ::User.find_by(uid: config['depositor_onyen'])
    current_file_name = nil
    
    # Find corresponding CSV row for file information
    csv_row = @csv_rows.find { |row| row['cdc_id'] == cdc_id }
    
    unless csv_row
      log_attachment_outcome(record,
                            category: :skipped,
                            message: 'No CSV row found',
                            file_name: 'N/A')
      return
    end
    
    begin
      # Attach main file (PDF)
      main_file = csv_row['main_file']
      if main_file.present?
        current_file_name = main_file
        file_path = File.join(@full_text_path, cdc_id, main_file)
        
        if File.exist?(file_path)
          file_set = attach_pdf_to_work_with_file_path!(
            record: record,
            file_path: file_path,
            depositor_onyen: config['depositor_onyen']
          )
          
          if file_set
            log_attachment_outcome(record,
                                  category: category_for_successful_attachment(record),
                                  message: 'Main PDF successfully attached',
                                  file_name: main_file)
          end
          
          sleep(SLEEP_INTERVAL)
        else
          log_attachment_outcome(record,
                                category: :failed,
                                message: 'Main file not found',
                                file_name: main_file)
        end
      end
      
      # Attach supplemental files
      supplemental_files = parse_pipe_delimited(csv_row['supplemental_files'])
      supplemental_files.each do |filename|
        current_file_name = filename
        file_path = File.join(@full_text_path, cdc_id, filename)
        
        unless File.exist?(file_path)
          log_attachment_outcome(record,
                                category: :failed,
                                message: 'Supplemental file not found',
                                file_name: filename)
          next
        end

        file_set = attach_file_set_to_work(
          work: work,
          file_path: file_path,
          user: depositor,
          visibility: Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
        )
        
        if file_set
          log_attachment_outcome(record,
                                category: category_for_successful_attachment(record),
                                message: 'Supplemental file successfully attached',
                                file_name: filename)
        end
        
        sleep(SLEEP_INTERVAL)
      end
      
    rescue => e
      Rails.logger.error("Error processing record #{cdc_id}: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      log_attachment_outcome(record,
                            category: :failed,
                            message: "Stacks File Attachment Error: #{e.message}",
                            file_name: current_file_name || 'unknown')
    end
  end

  def log_attachment_outcome(record, category:, message:, file_name:)
    # Use CDC ID to track seen records
    cdc_id = record.dig('ids', 'cdc_id')
    return if @existing_ids.include?(cdc_id) && cdc_id.present?
    @existing_ids << cdc_id if cdc_id.present?

    super(record, category: category, message: message, file_name: file_name)
  end

  private

  def load_csv_rows
    rows = []
    CSV.open(@input_csv_path, headers: true) do |csv|
      csv.each { |row| rows << row }
    end
    rows
  end

  def parse_pipe_delimited(field)
    return [] if field.blank? || field == '""'
    field.split('|').map(&:strip).reject(&:blank?)
  end
end