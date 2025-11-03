# frozen_string_literal: true
class Tasks::NsfIngest::Backlog::Utilities::MetadataIngestService
  include Tasks::IngestHelperUtils::IngestHelper
  include Tasks::NsfIngest::Backlog::Utilities::MetadataRetrievalHelper

  def initialize(config:, tracker:, md_ingest_results_path:)
    @config = config
    @file_info_csv_path = config['file_info_csv_path']
    @output_dir = config['output_dir']
    @md_ingest_results_path = md_ingest_results_path
    @admin_set = AdminSet.where(title: config['admin_set_title']).first
    @tracker = tracker
    @write_buffer = []
    @flush_threshold = 100
    @seen_doi_list = load_last_results
  end

  def process_backlog
    records_from_csv = remaining_records_from_csv(@seen_doi_list)

    records_from_csv.each do |record|
      next if @seen_doi_list.include?(record['doi']) && record['doi'].present?
      match = WorkUtilsHelper.fetch_work_data_by_doi(record['doi'])
      if match.present? && match[:work_id].present?
        skip_existing_work(record, match, filename: record['filename'])
        next
      end

      crossref_md = fetch_metadata_for_doi(source: 'crossref', doi: record['doi'])
      openalex_md = fetch_metadata_for_doi(source: 'openalex', doi: record['doi'])
      datacite_md = fetch_metadata_for_doi(source: 'datacite', doi: record['doi'])

      source = verify_source_md_available(crossref_md, openalex_md, record['doi'])
      resolved_md = merge_metadata_sources(crossref_md, openalex_md, datacite_md)
      attr_builder = construct_attribute_builder(resolved_md)

      article = new_article(resolved_md, attr_builder)
      record_result(category: :successfully_ingested_metadata_only, doi: record['doi'], article: article, filename: record['filename'])

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

  def new_article(metadata, attr_builder)
   # Create new work
    article = Article.new
    article.visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
    attr_builder.populate_article_metadata(article)
    article.save!

    # Sync permissions and state
    sync_permissions_and_state!(work_id: article.id, depositor_uid: @config['depositor_onyen'])
    article
  end

  def record_result(category:, message: '', doi: nil, article: nil, filename: nil)
    @seen_doi_list << doi if doi.present?
    ids = { 'doi' => doi }
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
    work_hash = WorkUtilsHelper.fetch_work_data_by_id(article.id)
    return if work_hash.blank?
    {
      'pmid' => work_hash[:pmid],
      'pmcid' => work_hash[:pmcid],
      'work_id' => work_hash[:work_id],
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
      result.dig('ids', 'doi')
    end.flatten.compact)
  end

  def remaining_records_from_csv(seen_doi_list)
    records = CSV.read(@file_info_csv_path, headers: true).map(&:to_h)
    records.reject do |record|
      doi = record['doi']
      doi.present? && seen_doi_list.include?(doi)
    end
  end

  def verify_source_md_available(crossref_md, openalex_md, doi)
    return if crossref_md && openalex_md

    if crossref_md.nil? && openalex_md.nil?
      raise "No metadata found from Crossref or OpenAlex for DOI #{doi}."
    end

    missing_source = crossref_md.nil? ? 'Crossref' : 'OpenAlex'
    chosen_source  = crossref_md.nil? ? 'OpenAlex' : 'Crossref'
    LogUtilsHelper.double_log(
      "No metadata found from #{missing_source} for DOI #{doi}. Using #{chosen_source} metadata.",
      :warn,
      tag: 'MetadataIngestService'
    )
  end


  def merge_metadata_sources(crossref_md, openalex_md, datacite_md)
    # Default to OpenAlex metadata if available else Crossref
    resolved_md = openalex_md || crossref_md
    resolved_md['source'] = openalex_md.present? ? 'openalex' : 'crossref'
    resolved_md['openalex_abstract'] = generate_openalex_abstract(openalex_md)
    resolved_md['datacite_abstract'] = datacite_md.dig('attributes', 'description') if datacite_md&.dig('attributes', 'description').present?
    resolved_md['openalex_keywords'] = extract_keywords_from_openalex(openalex_md)
    resolved_md
  end

  def construct_attribute_builder(resolved_md)
    case resolved_md['source']
    when 'openalex'
      Tasks::NsfIngest::Backlog::Utilities::AttributeBuilders::OpenalexAttributeBuilder.new(resolved_md, @admin_set, @config['depositor_onyen'])
    when 'crossref'
      Tasks::NsfIngest::Backlog::Utilities::AttributeBuilders::CrossrefAttributeBuilder.new(resolved_md, @admin_set, @config['depositor_onyen'])
    end
  end

  def skip_existing_work(record, match, filename: nil)
    Rails.logger.info("[MetadataIngestService] Skipping #{record.inspect} — work already exists.")
    article = WorkUtilsHelper.fetch_model_instance(match[:work_type], match[:work_id])
    record_result(category: :skipped, message: 'Pre-filtered: work exists', doi: record['doi'], article: article, filename: nil)
  end

  def handle_record_error(record, error, filename: nil)
    Rails.logger.error("[MetadataIngestService] Error processing record for DOI #{record['doi']}: #{error.message}")
    Rails.logger.error(error.backtrace.join("\n"))
    record_result(category: :failed, message: error.message, doi: record['doi'], article: nil, filename: filename)
  end
end
