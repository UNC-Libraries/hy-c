# frozen_string_literal: true
class Tasks::StacksIngest::Backlog::Utilities::MetadataIngestService
  API_REQUEST_DELAY_SECONDS = 3
  include Tasks::IngestHelperUtils::IngestHelper
  include Tasks::IngestHelperUtils::MetadataIngestHelper

  def initialize(config:, tracker:, md_ingest_results_path:)
    @config = config
    @output_dir = config['output_dir']
    @input_csv_path = config['input_csv_path']
    @md_ingest_results_path = md_ingest_results_path
    @admin_set = AdminSet.where(title: config['admin_set_title']).first
    @tracker = tracker
    @write_buffer = []
    @flush_threshold = 100
    @seen_identifier_list = load_last_results('cdc_id')
  end

  def identifier_key_name
    'cdc_id'
  end

  def process_backlog
    remaining_csv_rows = remaining_rows_from_csv(@input_csv_path)

    remaining_csv_rows.each do |row|
      id = row['cdc_id']
      filename = row['main_file']
      next if @seen_identifier_list.include?(id)
      # Skip if work with this Stacks ID already exists
      match = WorkUtilsHelper.fetch_work_data_by_alternate_identifier(id, admin_set_title: @config['admin_set_title'])
      if match.present? && match[:work_id].present?
        skip_existing_work(id, match, filename: filename)
        next
      end

      attr_builder, metadata = resolve_attr_builder_and_metadata_for_row(row)
      metadata['cdc_id'] = id
      article = new_article(metadata: metadata, attr_builder: attr_builder, config: @config)
      record_result(category: :successfully_ingested_metadata_only, identifier: id, article: article, filename: "#{id}.pdf")

      Rails.logger.info("[MetadataIngestService] Created new Article #{article.id} for publication with Stacks ID #{id}")
    rescue => e
      handle_record_error(id, e, filename: filename)
    ensure
      flush_buffer_if_needed
      # Respect rate limiting
      sleep(API_REQUEST_DELAY_SECONDS)
    end

    flush_buffer_to_file unless @write_buffer.empty?
    LogUtilsHelper.double_log("Ingest complete. Processed #{remaining_csv_rows.size} IDs.", :info, tag: 'MetadataIngestService')
  end

  private

  def resolve_attr_builder_and_metadata_for_row(row)
    cdc_id = row['cdc_id']
    doi = row['doi']
    resolver = nil
    raise ArgumentError, 'Stacks ID cannot be blank' if cdc_id.blank?
    if doi.present?
      resolver = Tasks::IngestHelperUtils::DoiMetadataResolver.new(
        doi: doi,
        admin_set: @admin_set,
        depositor_onyen: @config['depositor_onyen']
      )
    else
      resolver = Tasks::IngestHelperUtils::StacksIdMetadataResolver.new(
        cdc_id: cdc_id,
        admin_set: @admin_set,
        depositor_onyen: @config['depositor_onyen']
      )
    end
    attr_builder = resolver.resolve_and_build
    metadata = resolver.resolved_metadata
    return attr_builder, metadata
  rescue => e
    Rails.logger.error("Error resolving metadata for Stacks ID #{cdc_id}: #{e.message}")
    raise
  end

  def remaining_rows_from_csv(path)
    rows = []
    # Read CSV and extract rows
    CSV.open(path, headers: true) do |csv|
      csv.each do |row|
        rows << row
      end
    end
    rows.reject { |row| @seen_identifier_list.include?(row['cdc_id']) }
  end
end
