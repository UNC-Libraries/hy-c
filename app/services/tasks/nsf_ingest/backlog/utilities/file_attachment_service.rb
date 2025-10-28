# frozen_string_literal: true
class Tasks::NsfIngest::Backlog::Utilities::FileAttachmentService < Tasks::IngestHelperUtils::BaseFileAttachmentService
  SLEEP_INTERVAL = 1
  def initialize(config:, tracker:, log_file_path:, file_info_path:, metadata_ingest_result_path:)
    super(config: config, tracker: tracker, log_file_path: log_file_path, metadata_ingest_result_path: metadata_ingest_result_path)
    @file_info_path = file_info_path
    @metadata_ingest_result_path = metadata_ingest_result_path
    @existing_ids = load_seen_attachment_ids
    @records = fetch_attachment_candidates
    @doi_to_filenames = generate_doi_to_filenames
    @full_text_path = config['full_text_dir']
  end

  def process_record(record)
    record_id = record.dig('ids', 'work_id')
    filenames = @doi_to_filenames[record.dig('ids', 'doi')]
    begin
      filenames.each do |filename|
        file_path = File.join(@full_text_path, filename)
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
      end
  rescue =>  e
    Rails.logger.error("Error processing record #{record_id}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    log_attachment_outcome(record, category: :failed, message: "NSF File Attachment Error: #{e.message}", file_name: record['filename'])
    end
  end

  def generate_doi_to_filenames
    file_info_path = config['file_info_csv_path']
    res = {}
    CSV.foreach(file_info_path, headers: true) do |row|
      raw_doi = row['doi']&.strip
      fname = row['filename']&.strip
      next unless raw_doi && fname

      res[raw_doi] = [] unless res.key?(raw_doi)
      res[raw_doi] << fname
    end
    res
  end
end
