# frozen_string_literal: true
class Tasks::DTICIngest::Backlog::Utilities::MetadataIngestService
  include Tasks::IngestHelperUtils::IngestHelper
  include Tasks::IngestHelperUtils::MetadataIngestHelper

  def initialize(config:, tracker:, md_ingest_results_path:)
    @config = config
    @input_csv_path = config['input_csv_path']
    @output_dir = config['output_dir']
    @md_ingest_results_path = md_ingest_results_path
    @admin_set = AdminSet.where(title: config['admin_set_title']).first
    @tracker = tracker
    @write_buffer = []
    @flush_threshold = 100
    @seen_identifier_list = load_last_results('dtic_id')
  end

  def identifier_key_name
    'dtic_id'
  end

  def process_backlog
    records_from_csv = remaining_records_from_csv(@seen_identifier_list)

    records_from_csv.each do |record|
      dtic_id = record['filename'].split('.').first
      next if @seen_identifier_list.include?(dtic_id) && dtic_id.present?
      match = WorkUtilsHelper.fetch_work_data_by_alternate_identifier(dtic_id, admin_set_title: @config['admin_set_title'])
      if match.present? && match[:work_id].present?
        skip_existing_work(dtic_id, match, filename: record['filename'])
        next
      end


      attr_builder = Tasks::DTICIngest::Backlog::Utilities::AttributeBuilders::DTICAttributeBuilder.new(record, @admin_set, @config['depositor_onyen'])
      article = new_article(metadata: record, attr_builder: attr_builder, config: @config)
      record_result(category: :successfully_ingested_metadata_only, identifier: dtic_id, article: article, filename: record['filename'])

      Rails.logger.info("[MetadataIngestService] Created new Article #{article.id} for record #{record.inspect}")
    rescue => e
      handle_record_error(dtic_id, e, filename: record['filename'])
    ensure
      flush_buffer_if_needed
    end

    flush_buffer_to_file unless @write_buffer.empty?
    LogUtilsHelper.double_log("[MetadataIngestService] Ingest complete. Processed #{records_from_csv.size} records.", :info, tag: 'MetadataIngestService')
  end

  private

  def remaining_records_from_csv(seen_list)
    records = CSV.read(@input_csv_path, headers: true).map(&:to_h)
    records.reject do |record|
      dtic_id = record['filename'].split('.').first
      dtic_id.present? && seen_list.include?(dtic_id)
    end
  end
end
