# frozen_string_literal: true
class Tasks::NsfIngest::Backlog::Utilities::MetadataIngestService
  include Tasks::IngestHelper
  def initialize(config:, tracker:, md_ingest_results_path:)
    @config = config
    @file_info_csv = config['file_info_csv']
    @output_dir = config['output_dir']
    @record_ids = nil
    @md_ingest_results_path = md_ingest_results_path
    @admin_set = AdminSet.where(title: config['admin_set_title']).first
    @tracker = tracker
    @write_buffer = []
    @flush_threshold = 100
    @seen_doi_list = load_last_results
  end

  def load_last_results
    return Set.new unless File.exist?(@md_ingest_results_path)

    Set.new(
    File.readlines(@md_ingest_results_path).map do |line|
      result = JSON.parse(line.strip)
      result.dig('ids', 'doi')
    end.flatten.compact
    )
  end

  def remaining_records_from_csv(seen_doi_list)
    records = CSV.read(@file_info_csv, headers: true).map(&:to_h)
    records.reject do |record|
      doi = record['doi']
      doi.present? && seen_doi_list.include?(doi)
    end
  end

  def process_backlog
    # Read the CSV file
    records_from_csv = remaining_records_from_csv(@seen_doi_list)
    records_from_csv.each do |record|
      # Skip existing works in the results file
      next if @seen_doi_list.include?(record['doi']) && record['doi'].present?
      # Skip if record is in hyrax
      match = WorkUtilsHelper.find_best_work_match_by_alternate_id(**record.slice('pmid', 'pmcid', 'doi').symbolize_keys)
      if match.present? && match[:work_id].present?
        Rails.logger.info("[MetadataIngestService] Skipping #{record.inspect} — work already exists.")
        article = WorkUtilsHelper.fetch_model_instance(match[:work_type], match[:work_id])
        record_result(category: :skipped, message: 'Pre-filtered: work exists', ids: record.slice('pmid', 'pmcid', 'doi'), article: article)
        next
      end

      # WIP: Add logic to check if file exists in the retrieval directory
      # Retrieve metadata from Crossref
      metadata = crossref_metadata_for_doi(record['doi'])
      # Instantiate new article
      article = new_article(metadata)

      record_result(category: :successfully_ingested_metadata_only, ids: record.slice('pmid', 'pmcid', 'doi'), article: article)
      Rails.logger.info("[MetadataIngestService] Created new Article #{article.id} for record #{record.inspect}")
    rescue => e
      Rails.logger.error("[MetadataIngestService] Error processing record for DOI #{record['doi']}: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      record_result(category: :failed, message: e.message, ids: record.slice('pmid', 'pmcid', 'doi'))
    ensure
      flush_buffer_if_needed
    end
  end

  private

  def crossref_metadata_for_doi(doi)
    puts "Retrieving metadata for DOI: #{doi}"
    base_url = 'https://api.crossref.org/works/'
    url = URI.join(base_url, CGI.escape(doi))
    res = HTTParty.get(url)
    if res.code == 200
      metadata = JSON.parse(res.body)['message']
      new_article(metadata)
    else
      raise "Failed to retrieve metadata from Crossref for DOI #{doi}: HTTP #{res.code}"
    end
  end

  def new_article(metadata)
     # Create new work
    article = Article.new
    article.visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
    builder = Tasks::NsfIngest::Backlog::Utilities::CrossrefAttributeBuilder.new(metadata, article, @admin_set, @config['depositor_onyen'])
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
      # Merge article id into ids if article is provided
    log_entry = {
        ids: {
            pmid: ids['pmid'],
            pmcid: ids['pmcid'],
            doi: ids['doi'],
            work_id: article&.id
        },
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
    LogUtilsHelper.double_log("Flushed #{entries.size} entries to #{@md_ingest_results_path}", :info, tag: 'MetadataIngestService')
    rescue => e
      LogUtilsHelper.double_log("Failed to flush buffer to file: #{e.message}", :error, tag: 'MetadataIngestService')
      Rails.logger.error("Backtrace: #{e.backtrace.join("\n")}")
  end
end
