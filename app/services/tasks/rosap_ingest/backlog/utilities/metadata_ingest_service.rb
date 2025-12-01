# frozen_string_literal: true
class Tasks::RosapIngest::Backlog::Utilities::MetadataIngestService
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
    @seen_identifier_list = load_last_results('rosap_id')
  end

  def identifier_key_name
    'rosap_id'
  end

  def process_backlog
    rosap_ids = remaining_ids_from_directory(@config['full_text_dir'])

    rosap_ids.each do |id|
      next if @seen_identifier_list.include?(id)
      # Skip if work with this ROSA-P ID already exists
      match = WorkUtilsHelper.fetch_work_data_by_alternate_identifier(id, admin_set_title: @config['admin_set_title'])
      if match.present? && match[:work_id].present?
        skip_existing_work(id, match, filename: "#{id}.pdf")
        next
      end

      metadata = fetch_metadata_for_rosap_id(id)
      metadata['rosap_id'] = id
      attr_builder = Tasks::RosapIngest::Backlog::Utilities::AttributeBuilders::RosapAttributeBuilder.new(metadata, @admin_set, @config['depositor_onyen'])

      article = new_article(metadata: metadata, attr_builder: attr_builder, config: @config)
      record_result(category: :successfully_ingested_metadata_only, identifier: id, article: article, filename: "#{id}.pdf")

      Rails.logger.info("[MetadataIngestService] Created new Article #{article.id} for publication with ROSA-P ID #{id}")
    rescue => e
      handle_record_error(id, e, filename: "#{id}.pdf")
    ensure
      flush_buffer_if_needed
    end

    flush_buffer_to_file unless @write_buffer.empty?
    LogUtilsHelper.double_log("Ingest complete. Processed #{rosap_ids.size} IDs.", :info, tag: 'MetadataIngestService')
  end

  # Override for directory-specific recording
  def record_result(category:, message: '', identifier: nil, article: nil, filename: nil)
    identifier_key = identifier_key_name # Implemented by including class
    @seen_identifier_list << identifier if identifier.present?

    ids = { identifier_key => identifier, 'work_id' => article&.id&.to_s }
    alternate_ids = extract_alternate_ids_from_article(article, category)
    ids.merge!(alternate_ids) if alternate_ids.present?
    pdfs_in_dir = Dir.glob(File.join(@config['full_text_dir'], identifier, '*.pdf'))

    pdfs_in_dir.each do |pdf_path|
      log_entry = {
      ids: ids,
      timestamp: Time.now.utc.iso8601,
      category: category,
      filename: File.basename(pdf_path)
      }
      log_entry[:message] = message if message.present?

      @write_buffer << log_entry
      flush_buffer_if_needed
    end
  end

  private

  def fetch_metadata_for_rosap_id(rosap_id)
    raise ArgumentError, 'ROSA-P ID cannot be blank' if rosap_id.blank?
    response = HTTParty.get("https://rosap.ntl.bts.gov/view/dot/#{rosap_id}")
    if response.code != 200
      raise "Failed to fetch metadata for ROSA-P ID #{rosap_id}: HTTP #{response.code}"
    end

    Tasks::RosapIngest::Backlog::Utilities::HTMLParsingService.parse_metadata_from_html(response.body)
  end

  def remaining_ids_from_directory(path)
    # Extract ROSA-P IDs from PDFs in the specified directory
    ids = []
    Dir.glob(File.join(path, '*/')).each do |dir_path|
        # Get just the directory name (the ROSA-P ID)
      rosap_id = File.basename(dir_path)
      ids << rosap_id
    end
    ids.reject { |id| @seen_identifier_list.include?(id) }
  end
end
