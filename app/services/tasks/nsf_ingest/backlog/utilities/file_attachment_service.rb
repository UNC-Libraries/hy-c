# frozen_string_literal: true
class Tasks::NsfIngest::Backlog::Utilities::FileAttachmentService < Tasks::IngestHelperUtils::BaseFileAttachmentService
  def initialize(config:, tracker:, log_file_path:, file_info_path:, metadata_ingest_result_path:)
    super(config: config, tracker: tracker, log_file_path: log_file_path, metadata_ingest_result_path: metadata_ingest_result_path)
    @file_info_path = file_info_path
    @metadata_ingest_result_path = metadata_ingest_result_path
    @existing_ids = load_seen_attachment_ids
    @records = fetch_attachment_candidates
    @doi_to_filenames = generate_doi_to_filenames
    @full_text_path = config['file_retrieval_directory']
  end

  def process_record(record)
    record_id = record.dig('ids', 'work_id')
    filenames = @doi_to_filenames[record.dig('ids', 'doi')]
    begin
      filenames.each do |filename|
        resolved_filename =  normalized_filename_from_title(record: record) || filename
        file_path = File.join(@full_text_path, filename)
        file_set = attach_pdf_to_work_with_file_path!(record: record,
                                                file_path: file_path,
                                                depositor_onyen: config['depositor_onyen'],
                                                filename:  resolved_filename)
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
    log_attachment_outcome(record, category: :failed, message: "NSF File Attachment Error: #{e.message}", file_name: 'NONE')
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

  def normalized_filename_from_title(record:)
    work_hash = WorkUtilsHelper.fetch_work_data_by_id(record.dig('ids', 'work_id'))
    raw_title = work_hash[:title]
    words = raw_title.downcase
                  .gsub(/[^a-z0-9\s-]/, '')
                  .split
                  .reject { |w| %w[the and of a an to in].include?(w) }
                  .first(4) # keep up to 4 words

    base = words.join('_')
    prefix = base.truncate(25, omission: '')
    generate_filename_for_work(record.dig('ids', 'work_id'), prefix)
  end
end
