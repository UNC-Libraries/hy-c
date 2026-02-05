# frozen_string_literal: true
class Tasks::NASAIngest::Backlog::Utilities::FileAttachmentService < Tasks::IngestHelperUtils::BaseFileAttachmentService
  SLEEP_INTERVAL = 1
  def initialize(config:, tracker:, log_file_path:, metadata_ingest_result_path:)
    super(config: config, tracker: tracker, log_file_path: log_file_path, metadata_ingest_result_path: metadata_ingest_result_path)
    @metadata_ingest_result_path = metadata_ingest_result_path
    @existing_ids = load_seen_attachment_ids
    @records = fetch_attachment_candidates
    @data_dir = config['data_dir']
  end

  def process_record(record)
    nasa_id = record.dig('ids', 'nasa_id')

    begin
      # Find the directory for this NASA ID
      record_dir = File.join(@data_dir, nasa_id)

      unless Dir.exist?(record_dir)
        log_attachment_outcome(record,
                              category: :failed,
                              message: "Directory not found for NASA ID: #{nasa_id}",
                              file_name: nasa_id)
        return
      end

      # Get all PDF files in the directory
      pdf_files = Dir.glob(File.join(record_dir, '*.pdf'))

      if pdf_files.empty?
        log_attachment_outcome(record,
                              category: :failed,
                              message: "No PDF files found in directory: #{record_dir}",
                              file_name: nasa_id)
        return
      end

      # Attach each PDF
      pdf_files.each do |file_path|
        filename = File.basename(file_path)
        file_set = attach_pdf_to_work_with_file_path!(
          record: record,
          file_path: file_path,
          depositor_onyen: config['depositor_onyen']
        )

        if file_set
          log_attachment_outcome(record,
                                category: category_for_successful_attachment(record),
                                message: 'PDF successfully attached.',
                                file_name: filename)
        end

        sleep(SLEEP_INTERVAL)
      end

    rescue => e
      Rails.logger.error("Error processing record #{nasa_id}: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      log_attachment_outcome(record,
                            category: :failed,
                            message: "NASA File Attachment Error: #{e.message}",
                            file_name: nasa_id)
    end
  end
end
