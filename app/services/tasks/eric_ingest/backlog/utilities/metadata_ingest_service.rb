# frozen_string_literal: true
class Tasks::NsfIngest::Backlog::Utilities::MetadataIngestService
  include Tasks::IngestHelperUtils::IngestHelper
  include Tasks::NsfIngest::Backlog::Utilities::MetadataRetrievalHelper

  def initialize(config:, tracker:, md_ingest_results_path:)
    @config = config
    @output_dir = config['output_dir']
    @md_ingest_results_path = md_ingest_results_path
    @admin_set = AdminSet.where(title: config['admin_set_title']).first
    @tracker = tracker
    @write_buffer = []
    @flush_threshold = 100
    @seen_eric_id_list = load_last_results
  end

  def process_backlog
    eric_ids = remaining_ids_from_directory(@config['full_text_dir'])

    eric_ids.each do |id|
      next if @seen_eric_id_list.include?(id)
      metadata = fetch_metadata_for_eric_id(id)
      attr_builder = Tasks::EricIngest::Backlog::Utilities::AttributeBuilders::EricAttributeBuilder.new(metadata, @admin_set, @config['depositor_onyen'])

      article = new_article(metadata: resolved_md, attr_builder: attr_builder, config: @config)
      record_result(category: :successfully_ingested_metadata_only, eric_id: id, article: article, filename: "#{id}.pdf")

      Rails.logger.info("[MetadataIngestService] Created new Article #{article.id} for record #{record.inspect}")
    rescue => e
      handle_record_error(record, e, filename: record['filename'])
    ensure
      flush_buffer_if_needed
    end

    flush_buffer_to_file unless @write_buffer.empty?
    LogUtilsHelper.double_log("[MetadataIngestService] Ingest complete. Processed #{records_from_csv.size} records.", :info, tag: 'MetadataIngestService')
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

  def record_result(category:, message: '', eric_id: nil, article: nil, filename: nil)
    @seen_eric_id_list << eric_id if eric_id.present?
    ids = { 'eric_id' => eric_id, 'work_id' => article&.id&.to_s }
    ids.merge!(extract_alternate_ids_from_article(article, category) || {}) if article.present?

    log_entry = {
        ids: ids,
        timestamp: Time.now.utc.iso8601,
        category: category,
        filename: filename
    }
    log_entry[:message] = message if message.present?
    @write_buffer << log_entry
    flush_buffer_if_needed
  end

  def extract_alternate_ids_from_article(article, category)
    negative_categories = [:skipped, :skipped_non_unc_affiliation, :failed]
    return if article.nil? || negative_categories.include?(category)
    work_hash = WorkUtilsHelper.fetch_work_data_by_id(article.id, admin_set_title: @config['admin_set_title'])
    return if work_hash.blank?
    {
      'pmid' => work_hash[:pmid],
      'pmcid' => work_hash[:pmcid]
    }.compact
  end

  def flush_buffer_if_needed
    return if @write_buffer.size < @flush_threshold
    flush_buffer_to_file
  end

  def flush_buffer_to_file
    entries = @write_buffer.dup
    File.open(@md_ingest_results_path, 'a') { |file| entries.each { |entry| file.puts(entry.to_json) } }
    @write_buffer.clear
    LogUtilsHelper.double_log("Flushed #{entries.size} entries to #{@md_ingest_results_path}", :info, tag: self.class.name)
    rescue => e
      LogUtilsHelper.double_log("Failed to flush buffer to file: #{e.message}", :error, tag: self.class.name)
      Rails.logger.error("Backtrace: #{e.backtrace.join("\n")}")
  end

  def load_last_results
    return Set.new unless File.exist?(@md_ingest_results_path)
    Set.new(File.readlines(@md_ingest_results_path).map do |line|
      result = JSON.parse(line.strip)
      result.dig('ids', 'eric_id')
    end.flatten.compact)
  end

  def remaining_ids_from_directory(path)
    # Extract ERIC IDs from PDFs in the specified directory
    ids = []
    Dir.glob(File.join(path, '*.pdf')).each do |file_path|
      filename = File.basename(file_path)
      eric_id = filename.sub('.pdf', '')
      ids << eric_id
    end
    ids.reject { |id| @seen_eric_id_list.include?(id) }
  end

  def skip_existing_work(eric_id, match, filename: nil)
    Rails.logger.info("[MetadataIngestService] Skipping work with ID #{eric_id} — already exists.")
    article = WorkUtilsHelper.fetch_model_instance(match[:work_type], match[:work_id])
    record_result(category: :skipped, message: 'Pre-filtered: work exists', eric_id: eric_id, article: article, filename: nil)
  end

  def handle_record_error(eric_id, error, filename: nil)
    Rails.logger.error("[MetadataIngestService] Error processing work with ID #{eric_id}: #{error.message}")
    Rails.logger.error(error.backtrace.join("\n"))
    record_result(category: :failed, message: error.message, eric_id: eric_id, article: nil, filename: filename)
  end
end
