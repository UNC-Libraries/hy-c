# frozen_string_literal: true
class Tasks::NsfIngest::Backlog::Utilities::FileAttachmentService < Tasks::BaseFileAttachmentService
  def initialize(config:, tracker:, log_file_path:, file_info_path:, metadata_ingest_result_path:)
    super(config: config, tracker: tracker, log_file_path: log_file_path)
    @file_info_path = file_info_path
    @metadata_ingest_result_path = metadata_ingest_result_path
    @existing_ids = load_seen_attachment_ids
    @records = fetch_attachment_candidates
    @doi_to_filenames = generate_doi_to_filenames
    @full_text_path = config['file_retrieval_directory']
  end

  def process_record(record)
    record_id = record.dig('ids', 'article_id')
    filenames = @doi_to_filenames[record.dig('ids', 'doi')]
    begin
      filenames.each do |filename|
        generated_filename = generate_filename_for_work(record_id, record_id)
        file_path = File.join(@full_text_path, filename)
        file_set = attach_pdf_to_work_with_file_path!(record: record,
                                                file_path: file_path,
                                                depositor: config['depositor_onyen'],
                                                filename:  generated_filename)
        if file_set
          log_attachment_outcome(record,
                          category: category_for_successful_attachment(record),
                          message: 'PDF successfully attached.',
                          file_name: filename)
        end
      end
  rescue =>  e
    Rails.logger.error("Error processing record #{record_id}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    record_result(category: :failed, message: "NSF File Attachment Error: #{e.message}", ids: record.slice('pmid', 'pmcid', 'doi'))
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
