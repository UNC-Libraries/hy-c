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
    remaining_csv_rows = remaining_rows_from_csv(@seen_identifier_list)

    remaining_csv_rows.each do |row|
      id = row['stacks_id']
      filename = row['main_file']
      next if @seen_identifier_list.include?(id)
      # Skip if work with this Stacks ID already exists
      match = WorkUtilsHelper.fetch_work_data_by_alternate_identifier(id, admin_set_title: @config['admin_set_title'])
      if match.present? && match[:work_id].present?
        skip_existing_work(id, match, filename: filename)
        next
      end

      # metadata = fetch_metadata_for_stacks_id(id)
      # metadata['stacks_id'] = id
      # attr_builder = Tasks::RosapIngest::Backlog::Utilities::AttributeBuilders::RosapAttributeBuilder.new(metadata, @admin_set, @config['depositor_onyen'])

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

  def remaining_rows_from_csv(path)
    # Extract Stacks info from CSV
    rows = []
    CSV.foreach(path, headers: true) do |row|
      rows << row.to_h
    end
    rows.reject { |row| @seen_identifier_list.include?(row['stacks_id']) }
  end
end
