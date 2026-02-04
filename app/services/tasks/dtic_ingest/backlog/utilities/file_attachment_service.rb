# frozen_string_literal: true
class Tasks::DTICIngest::Backlog::Utilities::FileAttachmentService < Tasks::IngestHelperUtils::BaseFileAttachmentService
  SLEEP_INTERVAL = 1
  def initialize(config:, tracker:, log_file_path:, file_info_path:, metadata_ingest_result_path:)
    super(config: config, tracker: tracker, log_file_path: log_file_path, metadata_ingest_result_path: metadata_ingest_result_path)
    @file_info_path = file_info_path
    @metadata_ingest_result_path = metadata_ingest_result_path
    @existing_ids = load_seen_attachment_ids
    @records = fetch_attachment_candidates
    @full_text_path = config['full_text_dir']
  end

  def process_record(record)
    filename = record['filename']
    dtic_id = filename.split('.').first
    begin
      file_path = find_pdf_in_directory(@full_text_path, filename)

      if file_path.nil?
        log_attachment_outcome(record,
                              category: :failed,
                              message: "PDF file not found: #{filename}",
                              file_name: filename)
        return
      end

      file_set = attach_pdf_to_work_with_file_path!(record: record,
                                              file_path: file_path,
                                              depositor_onyen: config['depositor_onyen'])
      if file_set
        log_attachment_outcome(record,
                        category: category_for_successful_attachment(record),
                        message: 'PDF successfully attached.',
                        file_name: filename)
      end
      # Sleep briefly to avoid overwhelming fedora with rapid requests
      sleep(SLEEP_INTERVAL)
  rescue =>  e
    Rails.logger.error("Error processing record #{record_id}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    log_attachment_outcome(record, category: :failed, message: "DTIC File Attachment Error: #{e.message}", file_name: record['filename'])
    end
  end

  def log_attachment_outcome(record, category:, message:, file_name:)
    # Use the filename to track seen attachments
    dtic_id = record.dig('ids', 'dtic_id')
    return if @existing_ids.include?(dtic_id) && dtic_id.present?
    @existing_ids << dtic_id if dtic_id.present?

    super(record, category: category, message: message, file_name: file_name)
  end

  private

  def find_pdf_in_directory(base_path, filename)
    # Search recursively for the PDF
    Dir.glob(File.join(base_path, '**', filename)).first
  end
end
