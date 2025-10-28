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
      match = WorkUtilsHelper.find_best_work_match_by_alternate_id(**record.slice('pmid', 'pmcid', 'doi').symbolize_keys)
      if match.present? && match[:work_id].present?
        skip_existing_work(record, match)
        next
      end

      crossref_md = fetch_metadata_for_doi(source: 'crossref', doi: record['doi'])
      openalex_md = fetch_metadata_for_doi(source: 'openalex', doi: record['doi'])
      datacite_md = fetch_metadata_for_doi(source: 'datacite', doi: record['doi'])

      source = select_source(crossref_md, openalex_md, record['doi'])
      resolved_md = crossref_md || openalex_md
      merge_additional_metadata(resolved_md, openalex_md, datacite_md)

      article = new_article(resolved_md, source)
      record_result(category: :successfully_ingested_metadata_only, ids: record.slice('pmid', 'pmcid', 'doi'), article: article)

      Rails.logger.info("[MetadataIngestService] Created new Article #{article.id} for record #{record.inspect}")
    rescue => e
      handle_record_error(record, e)
    ensure
      flush_buffer_if_needed
    end

    flush_buffer_to_file unless @write_buffer.empty?
    LogUtilsHelper.double_log("[MetadataIngestService] Ingest complete. Processed #{records_from_csv.size} records.", :info, tag: 'MetadataIngestService')
  end

  private

  def new_article(metadata, source)
   # Create new work
    article = Article.new
    article.visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
    builder = if source == 'openalex'
                Tasks::NsfIngest::Backlog::Utilities::AttributeBuilders::OpenalexAttributeBuilder.new(metadata, article, @admin_set, @config['depositor_onyen'])
    else
      Tasks::NsfIngest::Backlog::Utilities::AttributeBuilders::CrossrefAttributeBuilder.new(metadata, article, @admin_set, @config['depositor_onyen'])
    end
    builder.populate_article_metadata
    article.save!

    # Sync permissions and state
    sync_permissions_and_state!(article.id, @config['depositor_onyen'])
    article
  end

  def record_result(category:, message: '', ids: {}, article: nil)
    doi = ids['doi']
    return if @seen_doi_list.include?(doi) && doi.present?
    @seen_doi_list << doi if doi.present?

    log_entry = {
        ids: ids.merge('work_id' => article&.id),
        timestamp: Time.now.utc.iso8601,
        category: category
    }
    log_entry[:message] = message if message.present?
    @write_buffer << log_entry
    flush_buffer_if_needed
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

  def select_source(crossref_md, openalex_md, doi)
    if crossref_md.nil? && openalex_md.nil?
      raise "No metadata found from Crossref or OpenAlex."
    end
    if crossref_md.nil?
      LogUtilsHelper.double_log("No metadata found from Crossref for DOI #{doi}. Falling back to OpenAlex metadata.", :warn, tag: 'MetadataIngestService')
      'openalex'
    else
      'crossref'
    end
  end

  def merge_additional_metadata(resolved_md, openalex_md, datacite_md)
    resolved_md['openalex_abstract'] = generate_openalex_abstract(openalex_md)
    resolved_md['datacite_abstract'] = datacite_md.dig('attributes', 'description') if datacite_md&.dig('attributes', 'description').present?
    resolved_md['openalex_keywords'] = extract_keywords_from_openalex(openalex_md)
  end

  def parse_response(res, source, doi)
    parsed = JSON.parse(res.body)
    case source
    when 'crossref' then parsed['message']
    when 'openalex' then parsed
    when 'datacite' then parsed['data']
    end
  end

  def skip_existing_work(record, match)
    Rails.logger.info("[MetadataIngestService] Skipping #{record.inspect} — work already exists.")
    article = WorkUtilsHelper.fetch_model_instance(match[:work_type], match[:work_id])
    record_result(category: :skipped, message: 'Pre-filtered: work exists', ids: record.slice('pmid', 'pmcid', 'doi'), article: article)
  end

  def handle_record_error(record, error)
    Rails.logger.error("[MetadataIngestService] Error processing record for DOI #{record['doi']}: #{error.message}")
    Rails.logger.error(error.backtrace.join("\n"))
    record_result(category: :failed, message: error.message, ids: record.slice('pmid', 'pmcid', 'doi'))
  end
end
