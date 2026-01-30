# frozen_string literal: true
class Tasks::OstiIngest::Backlog::Utilities::FileAttachmentService < Tasks::IngestHelperUtils::BaseFileAttachmentService
  SLEEP_INTERVAL = 1
  def initialize(config:, tracker:, log_file_path:, metadata_ingest_result_path:)
    super(config: config, tracker: tracker, log_file_path: log_file_path, metadata_ingest_result_path: metadata_ingest_result_path)
    @existing_ids = load_seen_attachment_ids
    @data_dir = config['data_dir']
  end

  def process_record(record)
    record_id = record.dig('ids', 'work_id')
    osti_id = record.dig('ids', 'osti_id')
    file_path = File.join(@data_dir, osti_id)
    current_file_name = nil

    # Find all PDFs in the directory
    pdf_files = Dir.glob(File.join(file_path, '*.pdf'))

    # If no PDFs found, log as skipped
    if pdf_files.empty?
      log_attachment_outcome(record,
                            category: :successfully_ingested_metadata_only,
                            message: 'No PDF files found in directory',
                            file_name: 'N/A')
      return
    end

    # Attach all PDFs
    begin
      pdf_files.each do |file_pdf_path|
        current_file_name = File.basename(file_pdf_path)
        file_set = attach_pdf_to_work_with_file_path!(record: record,
                                                file_path: file_pdf_path,
                                                depositor_onyen: config['depositor_onyen'])

        if file_set
          log_attachment_outcome(record,
                          category: category_for_successful_attachment(record),
                          message: 'PDF successfully attached.',
                          file_name: current_file_name)
        end
        # Sleep briefly to avoid overwhelming fedora with rapid requests
        sleep(SLEEP_INTERVAL)
      end
    rescue => e
      Rails.logger.error("Error processing record #{record_id}: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      log_attachment_outcome(record,
                            category: :failed,
                            message: "OSTI File Attachment Error: #{e.message}",
                            file_name: current_file_name || 'unknown')
    end
  end

  def log_attachment_outcome(record, category:, message:, file_name:)
      # Use OSTI ID to track seen records, all OSTI records should have a OSTI ID
    osti_id = record.dig('ids', 'osti_id')
    return if @existing_ids.include?(osti_id) && osti_id.present?
    @existing_ids << osti_id if osti_id.present?

    super(record, category: category, message: message, file_name: file_name)
  end
end
