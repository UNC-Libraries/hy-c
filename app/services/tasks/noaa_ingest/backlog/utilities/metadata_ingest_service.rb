# frozen_string_literal: true
class Tasks::NoaaIngest::Backlog::Utilities::MetadataIngestService
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
    @seen_identifier_list = load_last_results('noaa_id')
  end

  def identifier_key_name
    'noaa_id'
  end

  def process_backlog
    remaining_csv_rows = remaining_rows_from_csv(@input_csv_path)

    remaining_csv_rows.each do |row|
      id = row['noaa_id']
      filename = row['main_file']
      next if @seen_identifier_list.include?(id)
      # Skip if work with this NOAA ID already exists
      match = WorkUtilsHelper.fetch_work_data_by_alternate_identifier(id, admin_set_title: @config['admin_set_title'])
      if match.present? && match[:work_id].present?
        skip_existing_work(id, match, filename: filename)
        next
      end

      attr_builder, metadata = resolve_attr_builder_and_metadata_for_row(row)
      article = new_article(metadata: metadata, attr_builder: attr_builder, config: @config, noaa_id: id)
      record_result(category: :successfully_ingested_metadata_only, identifier: id, article: article, filename: "#{id}.pdf")

      Rails.logger.info("[MetadataIngestService] Created new Article #{article.id} for publication with NOAA ID #{id}")
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

  # IngestHelper method override
  def new_article(metadata:, attr_builder:, config:, cdc_id:)
    # Create new work
    article = Article.new
    article.visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
    attr_builder.populate_article_metadata(article)
    # Override: Add NOAA ID to identifiers
    article.identifier << "NOAA ID: #{cdc_id}"
    article.save!

    # Sync permissions and state
    admin_set = AdminSet.where(title: config['admin_set_title'])&.first
    sync_permissions_and_state!(work_id: article.id, depositor_uid: config['depositor_onyen'], admin_set: admin_set)
    article
  end


  def resolve_attr_builder_and_metadata_for_row(row)
    cdc_id = row['cdc_id']
    doi = row['doi']
    raise ArgumentError, 'NOAA ID cannot be blank' if cdc_id.blank?

    attr_builder, metadata = resolve_metadata(cdc_id: cdc_id, doi: doi)

    [attr_builder, metadata]
  rescue => e
    Rails.logger.error("Error resolving metadata for NOAA ID #{cdc_id}: #{e.message}")
    raise
  end

  private

  def resolve_metadata(cdc_id:, doi:)
    if doi.present?
      try_doi_resolver(cdc_id: cdc_id, doi: doi)
    else
      oai_pmh_resolver(cdc_id)
    end
  end

  def try_doi_resolver(cdc_id:, doi:)
    resolver = Tasks::IngestHelperUtils::DoiMetadataResolver.new(
      doi: doi,
      admin_set: @admin_set,
      depositor_onyen: @config['depositor_onyen']
    )
    [resolver.resolve_and_build, resolver.resolved_metadata]
  rescue => e
    Rails.logger.warn("[MetadataIngestService] DOI resolution failed for DOI #{doi} (NOAA ID #{cdc_id}): #{e.message}. Falling back to OAI-PMH.")
    oai_pmh_resolver(cdc_id)
  end

  def oai_pmh_resolver(cdc_id)
    resolver = Tasks::IngestHelperUtils::OaiPmhMetadataResolver.new(
      id: cdc_id,
      identifier_key_name: identifier_key_name,
      full_text_dir: @config['full_text_dir'],
      admin_set: @admin_set,
      depositor_onyen: @config['depositor_onyen']
    )
    [resolver.resolve_and_build, resolver.resolved_metadata]
  end

  def remaining_rows_from_csv(path)
    rows = []
    # Read CSV and extract rows
    CSV.open(path, headers: true) do |csv|
      csv.each do |row|
        rows << row unless @seen_identifier_list.include?(row['cdc_id'])
      end
    end
    rows
  end
end
