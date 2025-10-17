# frozen_string_literal: true
class Tasks::NsfIngest::Backlog::Utilities::FileAttachmentService < Tasks::BaseFileAttachmentService
  def initialize(config:, tracker:, output_path:, file_directory_path:, metadata_ingest_result_path:)
    super(config: config, tracker: tracker, output_path: output_path)
    @log_file = File.join(output_path, 'attachment_results.jsonl')
    @file_directory_path = file_directory_path
    @metadata_ingest_result_path = metadata_ingest_result_path
    @existing_ids = load_seen_attachment_ids
    @records = fetch_attachment_candidates
  end
end
