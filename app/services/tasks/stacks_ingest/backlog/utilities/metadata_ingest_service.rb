# frozen_string_literal: true
class Tasks::StacksIngest::Backlog::Utilities::MetadataIngestService
  include Tasks::IngestHelperUtils::IngestHelper
  include Tasks::IngestHelperUtils::MetadataIngestHelper

  def initialize(config:, tracker:, md_ingest_results_path:)
    @config = config
    @output_dir = config['output_dir']
    @md_ingest_results_path = md_ingest_results_path
    @admin_set = AdminSet.where(title: config['admin_set_title']).first
    @tracker = tracker
    @write_buffer = []
    @flush_threshold = 100
    @seen_identifier_list = load_last_results('stacks_id')
  end

  def identifier_key_name
    'stacks_id'
  end

  def process_backlog
    stacks_ids = remaining_ids_from_directory(@config['full_text_dir'])

    stacks_ids.each do |id|
      next if @seen_identifier_list.include?(id)
      # Skip if work with this Stacks ID already exists
      match = WorkUtilsHelper.fetch_work_data_by_alternate_identifier(id, admin_set_title: @config['admin_set_title'])
      if match.present? && match[:work_id].present?
        skip_existing_work(id, match, filename: "#{id}.pdf")
        next
      end

      metadata = fetch_metadata_for_stacks_id(id)
      metadata['stacks_id'] = id
      attr_builder = Tasks::RosapIngest::Backlog::Utilities::AttributeBuilders::RosapAttributeBuilder.new(metadata, @admin_set, @config['depositor_onyen'])

      article = new_article(metadata: metadata, attr_builder: attr_builder, config: @config)
      record_result(category: :successfully_ingested_metadata_only, identifier: id, article: article, filename: "#{id}.pdf")

      Rails.logger.info("[MetadataIngestService] Created new Article #{article.id} for publication with Stacks ID #{id}")
    rescue => e
      handle_record_error(id, e, filename: "#{id}.pdf")
    ensure
      flush_buffer_if_needed
      # Respect rate limiting
      sleep(API_REQUEST_DELAY_SECONDS)
    end

    flush_buffer_to_file unless @write_buffer.empty?
    LogUtilsHelper.double_log("Ingest complete. Processed #{stacks_ids.size} IDs.", :info, tag: 'MetadataIngestService')
  end

  private

  def fetch_metadata_for_stacks_id(stacks_id)
    raise ArgumentError, 'Stacks ID cannot be blank' if stacks_id.blank?
    response = HTTParty.get("https://stacks.ntl.bts.gov/view/dot/#{stacks_id}")
    if response.code != 200
      raise "Failed to fetch metadata for Stacks ID #{stacks_id}: HTTP #{response.code}"
    end

    Tasks::RosapIngest::Backlog::Utilities::HTMLParsingService.parse_metadata_from_html(response.body)
  end

  def remaining_ids_from_directory(path)
    # Extract Stacks IDs from PDFs in the specified directory
    ids = []
    Dir.glob(File.join(path, '*/')).each do |dir_path|
        # Get just the directory name (the Stacks ID)
      stacks_id = File.basename(dir_path)
      ids << stacks_id
    end
    ids.reject { |id| @seen_identifier_list.include?(id) }
  end
end
