# frozen_string_literal: true
class Tasks::EricIngest::Backlog::Utilities::MetadataIngestService
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
    @seen_identifier_list = load_last_results('eric_id')
  end

  def identifier_key_name
    'eric_id'
  end

  def process_backlog
    eric_ids = remaining_ids_from_directory(@config['full_text_dir'])

    eric_ids.each do |id|
      next if @seen_identifier_list.include?(id)
      metadata = fetch_metadata_for_eric_id(id)
      metadata['eric_id'] = id
      attr_builder = Tasks::EricIngest::Backlog::Utilities::AttributeBuilders::EricAttributeBuilder.new(metadata, @admin_set, @config['depositor_onyen'])

      article = new_article(metadata: metadata, attr_builder: attr_builder, config: @config)
      record_result(category: :successfully_ingested_metadata_only, identifier: id, article: article, filename: "#{id}.pdf")

      Rails.logger.info("[MetadataIngestService] Created new Article #{article.id} for publication with ERIC ID #{id}")
    rescue => e
      handle_record_error(id, e, filename: "#{id}.pdf")
    ensure
      flush_buffer_if_needed
    end

    flush_buffer_to_file unless @write_buffer.empty?
    LogUtilsHelper.double_log("Ingest complete. Processed #{eric_ids.size} IDs.", :info, tag: 'MetadataIngestService')
  end

  private

  def fetch_metadata_for_eric_id(eric_id)
    raise ArgumentError, 'ERIC ID cannot be blank' if eric_id.blank?
    uri = URI('https://api.ies.ed.gov/eric/')
    uri.query = URI.encode_www_form(search: "id:\"#{eric_id}\"")

    response = HTTParty.get(uri.to_s)
    if response.code != 200
      raise "Failed to fetch metadata for ERIC ID #{eric_id}: HTTP #{response.code}"
    end

    extract_json_from_response(response)
  end

  def extract_json_from_response(response)
    data = JSON.parse(response.body)
    if data['response'] && data['response']['docs'] && data['response']['docs'].any?
      return data['response']['docs'].first
    else
      raise 'No metadata found in response for ERIC ID'
    end
  end

  def remaining_ids_from_directory(path)
    # Extract ERIC IDs from PDFs in the specified directory
    ids = []
    Dir.glob(File.join(path, '*.pdf')).each do |file_path|
      filename = File.basename(file_path)
      eric_id = filename.sub('.pdf', '')
      ids << eric_id
    end
    ids.reject { |id| @seen_identifier_list.include?(id) }
  end
end
