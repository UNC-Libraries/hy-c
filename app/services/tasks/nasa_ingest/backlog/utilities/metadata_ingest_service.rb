# frozen_string_literal: true
class Tasks::NASAIngest::Backlog::Utilities::MetadataIngestService
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
    @seen_identifier_list = load_last_results('nasa_id')
  end

  def identifier_key_name
    'nasa_id'
  end

  def process_backlog
    remaining_ids_from_data_dir = remaining_ids_from_data_dir()

    remaining_ids_from_data_dir.each do |nasa_id|
      next if @seen_identifier_list.include?(nasa_id)
      metadata_json = metadata_json_for_nasa_id(nasa_id)
      # Skip if work with this NASA ID
      match = WorkUtilsHelper.fetch_work_data_by_alternate_identifier(nasa_id, admin_set_title: @config['admin_set_title'])
      if match.present? && match[:work_id].present?
        skip_existing_work(nasa_id, match, filename: "#{nasa_id}.pdf")
        next
      end

      attr_builder = Tasks::NASAIngest::Backlog::Utilities::AttributeBuilders::NASAAttributeBuilder.new(metadata_json, @admin_set, @config['depositor_onyen'])
      article = new_article(metadata: metadata_json, attr_builder: attr_builder, config: @config, nasa_id: nasa_id)
      record_result(category: :successfully_ingested_metadata_only, identifier: nasa_id, article: article, filename: "#{nasa_id}.pdf")

      Rails.logger.info("[MetadataIngestService] Created new Article #{article.id} for publication with NASA ID #{nasa_id}")
  rescue => e
    handle_record_error(nasa_id, e, filename: "#{nasa_id}.pdf")
  ensure
    flush_buffer_if_needed
      # Respect rate limiting
    sleep(API_REQUEST_DELAY_SECONDS)
    end

    flush_buffer_to_file unless @write_buffer.empty?
    LogUtilsHelper.double_log("Ingest complete. Processed #{remaining_ids_from_data_dir.size} IDs.", :info, tag: 'MetadataIngestService')
  end

  # IngestHelper method override
  def new_article(metadata:, attr_builder:, config:, nasa_id:)
    # Create new work
    article = Article.new
    article.visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
    attr_builder.populate_article_metadata(article)
    # WIP Remove Later -----------
    # Override: Add NASA ID to identifiers
    # article.identifier << "NASA ID: #{nasa_id}"
    # Override: Use backlog abstract if present
    # NASA backlog abstracts are generally higher quality than those retrieved via DOI resolution
    # if metadata['backlog_abstract'].present?
    #   article.abstract = [metadata['backlog_abstract']]
    # end
    # Remove HTML tags from title
    # article.title = [sanitize_text(article.title.first)]

    # Override: Replace creators with NASA authors
    # article.creators.clear
    # article.creators_attributes = parse_nasa_authors(metadata['authors'])

    article.save!

    # Sync permissions and state
    admin_set = AdminSet.where(title: config['admin_set_title'])&.first
    sync_permissions_and_state!(work_id: article.id, depositor_uid: config['depositor_onyen'], admin_set: admin_set)
    article
  end


  def resolve_attr_builder_and_metadata_for_json(metadata_json)
    nasa_id = metadata_json['nasa_id']
    doi = metadata_json['doi']
    raise ArgumentError, 'NASA ID cannot be blank' if nasa_id.blank?

    attr_builder, metadata = resolve_metadata(nasa_id: nasa_id, doi: doi)
    metadata['backlog_abstract'] = metadata_json['description']
    metadata['authors'] = metadata_json['authors']

    [attr_builder, metadata]
  rescue => e
    Rails.logger.error("Error resolving metadata for NASA ID #{nasa_id}: #{e.message}")
    raise
  end

  private

  # IDs are derived from folder names in data directory
  def remaining_ids_from_data_dir
    Dir.entries(@data_dir)
     .reject { |f| f.start_with?('.') || @seen_identifier_list.include?(f) }
  end

  def metadata_json_for_nasa_id(nasa_id)
    path = File.join(@data_dir, nasa_id, 'metadata.json')
    return nil unless File.exist?(path)

    file_content = File.read(path)
    JSON.parse(file_content)
  rescue => e
    Rails.logger.error("Error reading metadata.json for NASA ID #{nasa_id}: #{e.message}")
    raise e
  end
end
