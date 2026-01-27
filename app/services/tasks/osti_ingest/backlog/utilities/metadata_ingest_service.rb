# frozen_string_literal: true
class Tasks::OstiIngest::Backlog::Utilities::MetadataIngestService
  API_REQUEST_DELAY_SECONDS = 3
  include Tasks::IngestHelperUtils::IngestHelper
  include Tasks::IngestHelperUtils::MetadataIngestHelper

  def initialize(config:, tracker:, md_ingest_results_path:)
    @config = config
    @output_dir = config['output_dir']
    @data_dir = config['data_dir']
    @md_ingest_results_path = md_ingest_results_path
    @admin_set = AdminSet.where(title: config['admin_set_title']).first
    @tracker = tracker
    @write_buffer = []
    @flush_threshold = 100
    @seen_identifier_list = load_last_results('osti_id')
  end

  def identifier_key_name
    'osti_id'
  end

  def process_backlog
    remaining_ids_from_data_dir = remaining_ids_from_data_dir()

    remaining_ids_from_data_dir.each do |osti_id|
      next if @seen_identifier_list.include?(osti_id)
      metadata_json = metadata_json_for_osti_id(osti_id)
      # Skip if work with this OSTI ID or DOI already exists
      match = WorkUtilsHelper.fetch_work_data_by_alternate_identifier(osti_id, admin_set_title: @config['admin_set_title']) ||
      WorkUtilsHelper.fetch_work_data_by_doi(metadata_json['doi'], admin_set_title: @config['admin_set_title'])
      if match.present? && match[:work_id].present?
        skip_existing_work(osti_id, match, filename: filename)
        next
      end

      attr_builder, metadata = resolve_attr_builder_and_metadata_for_json(metadata_json)
      article = new_article(metadata: metadata, attr_builder: attr_builder, config: @config, osti_id: osti_id)
      record_result(category: :successfully_ingested_metadata_only, identifier: osti_id, article: article, filename: "#{osti_id}.pdf")

      Rails.logger.info("[MetadataIngestService] Created new Article #{article.id} for publication with OSTI ID #{osti_id}")
  rescue => e
    handle_record_error(osti_id, e, filename: filename)
  ensure
    flush_buffer_if_needed
      # Respect rate limiting
    sleep(API_REQUEST_DELAY_SECONDS)
    end

    flush_buffer_to_file unless @write_buffer.empty?
    LogUtilsHelper.double_log("Ingest complete. Processed #{remaining_ids_from_data_dir.size} IDs.", :info, tag: 'MetadataIngestService')
  end

  # IngestHelper method override
  def new_article(metadata:, attr_builder:, config:, osti_id:)
    # Create new work
    article = Article.new
    article.visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
    attr_builder.populate_article_metadata(article)
    # Override: Add OSTI ID to identifiers
    article.identifier << "OSTI ID: #{osti_id}"
    # Override: Use backlog abstract if present
    # OSTI backlog abstracts are generally higher quality than those retrieved via DOI resolution
    if metadata['backlog_abstract'].present?
      article.abstract = [metadata['backlog_abstract']]
    end
    # Remove HTML tags from title
    article.title = [sanitize_text(article.title.first)]
    article.save!

    # Sync permissions and state
    admin_set = AdminSet.where(title: config['admin_set_title'])&.first
    sync_permissions_and_state!(work_id: article.id, depositor_uid: config['depositor_onyen'], admin_set: admin_set)
    article
  end


  def resolve_attr_builder_and_metadata_for_json(metadata_json)
    osti_id = metadata_json['osti_id']
    doi = metadata_json['doi']
    raise ArgumentError, 'OSTI ID cannot be blank' if osti_id.blank?

    attr_builder, metadata = resolve_metadata(osti_id: osti_id, doi: doi)
    metadata['backlog_abstract'] = metadata_json['description']

    [attr_builder, metadata]
  rescue => e
    Rails.logger.error("Error resolving metadata for OSTI ID #{osti_id}: #{e.message}")
    raise
  end

  private

  def sanitize_text(text)
    return nil if text.blank?
    # Strip all HTML tags (including <scp>, <sup>, etc.)
    cleaned = ActionController::Base.helpers.strip_tags(text)
    cleaned.strip
  end

  def resolve_metadata(osti_id:, doi:)
    if doi.present?
      try_doi_resolver(osti_id: osti_id, doi: doi)
    else
      raise ArgumentError, "No DOI present for OSTI ID #{osti_id}; cannot resolve metadata."
    end
  end

  def try_doi_resolver(osti_id:, doi:)
    resolver = Tasks::IngestHelperUtils::DoiMetadataResolver.new(
      doi: doi,
      admin_set: @admin_set,
      depositor_onyen: @config['depositor_onyen']
    )
    [resolver.resolve_and_build, resolver.resolved_metadata]
  rescue => e
    raise "DOI resolution failed for OSTI ID #{osti_id} with DOI #{doi}: #{e.message}"
  end

  # IDs are derived from folder names in data directory
  def remaining_ids_from_data_dir
    Dir.entries(@data_dir)
     .reject { |f| f.start_with?('.') || @seen_identifier_list.include?(f) }
  end

  def metadata_json_for_osti_id(osti_id)
    path = File.join(@data_dir, osti_id, 'metadata.json')
    return nil unless File.exist?(path)
    
    file_content = File.read(path)
    JSON.parse(file_content)
  rescue => e
    Rails.logger.error("Error reading metadata.json for OSTI ID #{osti_id}: #{e.message}")
    raise e
  end
end
