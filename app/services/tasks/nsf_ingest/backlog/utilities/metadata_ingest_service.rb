# frozen_string_literal: true
class Tasks::NsfIngest::Backlog::Utilities::MetadataIngestService
  include Tasks::IngestHelperUtils::IngestHelper
  include Tasks::IngestHelperUtils::MetadataIngestHelper

  def initialize(config:, tracker:, md_ingest_results_path:)
    @config = config
    @file_info_csv_path = config['file_info_csv_path']
    @output_dir = config['output_dir']
    @md_ingest_results_path = md_ingest_results_path
    @admin_set = AdminSet.where(title: config['admin_set_title']).first
    @tracker = tracker
    @write_buffer = []
    @flush_threshold = 100
    @seen_identifier_list = load_last_results('doi')
  end

  def identifier_key_name
    'doi'
  end

  def process_backlog
    records_from_csv = remaining_records_from_csv(@seen_identifier_list)

    records_from_csv.each do |record|
      doi = record['doi']
      next if @seen_identifier_list.include?(doi) && doi.present?
      match = WorkUtilsHelper.fetch_work_data_by_doi(doi, admin_set_title: @config['admin_set_title'])
      if match.present? && match[:work_id].present?
        skip_existing_work(doi, match, filename: record['filename'])
        next
      end

      resolver = Tasks::IngestHelperUtils::DoiMetadataResolver.new(
        doi: doi,
        admin_set: @admin_set,
        depositor_onyen: @config['depositor_onyen']
      )
      attr_builder = resolver.resolve_and_build

      article = new_article(metadata: resolver.resolved_metadata, attr_builder: attr_builder, config: @config)
      record_result(category: :successfully_ingested_metadata_only, identifier: doi, article: article, filename: record['filename'])

      Rails.logger.info("[MetadataIngestService] Created new Article #{article.id} for record #{record.inspect}")
    rescue => e
      handle_record_error(doi, e, filename: record['filename'])
    ensure
      flush_buffer_if_needed
    end

    flush_buffer_to_file unless @write_buffer.empty?
    LogUtilsHelper.double_log("[MetadataIngestService] Ingest complete. Processed #{records_from_csv.size} records.", :info, tag: 'MetadataIngestService')
  end

  private

  def remaining_records_from_csv(seen_list)
    records = CSV.read(@file_info_csv_path, headers: true).map(&:to_h)
    records.reject do |record|
      doi = record['doi']
      doi.present? && seen_list.include?(doi)
    end
  end
end
