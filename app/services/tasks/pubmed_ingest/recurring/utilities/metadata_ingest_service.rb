# frozen_string_literal: true
class Tasks::PubmedIngest::Recurring::Utilities::MetadataIngestService
  def initialize(config:, tracker:, md_ingest_results_path:)
    @config = config
    @output_dir = config['output_dir']
    @record_ids = nil
    @md_ingest_results_path = md_ingest_results_path
    @admin_set = AdminSet.where(title: config['admin_set_title']).first
    @tracker = tracker
    @write_buffer = []
    @flush_threshold = 200
  end

  def load_alternate_ids_from_file(path:)
    LogUtilsHelper.double_log("Loading IDs from file with alt ids: #{path}", :info, tag: 'MetadataIngestService')
    filtered_ids = []
    existing_ids = load_last_results
    count = 0

    File.foreach(path) do |line|
      count += 1
      record = JSON.parse(line.strip)
      # Skip existing works in the results file
      next if existing_ids.include?(record['pmid']) || existing_ids.include?(record['pmcid'])
      # Skip if record is in hyrax
      match = find_best_work_match(record.slice('pmid', 'pmcid', 'doi'))
      if match.present? && match[:work_id].present?
        Rails.logger.info("[MetadataIngestService] Skipping #{record.inspect} — work already exists.")
        article = WorkUtilsHelper.fetch_model_instance(match[:work_type], match[:work_id])
        record_result(category: :skipped, message: 'Pre-filtered: work exists', ids: record, article: article)
        next
      end

      filtered_ids << record
    end

    @record_ids = filtered_ids
    # LogUtilsHelper.double_log("Skipped #{count - filtered_ids.size} records that already existed in results file.", :info, tag: 'MetadataIngestService')
    LogUtilsHelper.double_log("Filtered #{count - filtered_ids.size} records that already existed in results file or were already in Hyrax.", :info, tag: 'MetadataIngestService')
    flush_buffer_to_file unless @write_buffer.empty?
  end

  def load_last_results
    return Set.new unless File.exist?(@md_ingest_results_path)

    Set.new(
      File.readlines(@md_ingest_results_path).map do |line|
        result = JSON.parse(line.strip)
        [result.dig('ids', 'pmid'), result.dig('ids', 'pmcid')]
      end.flatten.compact
    )
  end


  def batch_retrieve_and_process_metadata(batch_size: 200, db:)
    LogUtilsHelper.double_log("Starting batch retrieval and processing for #{db} with batch size #{batch_size}", :info, tag: 'MetadataIngestService')
    return if @record_ids.nil? || @record_ids.empty?
    number_of_batches = (@record_ids.size / batch_size.to_f).ceil
    batch_count = 1
    @record_ids.each_slice(batch_size) do |batch|
      batch_ids = batch.map { |record| db == 'pubmed' ? record['pmid'] : record['pmcid']&.delete_prefix('PMC') }.compact
      next if batch_ids.empty?
      base_url = 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi'
      query_params = "?db=#{db}&id=#{batch_ids.join(',')}&retmode=xml&tool=CDR&email=cdr@unc.edu"
      LogUtilsHelper.double_log("Processing batch #{batch_count}/#{number_of_batches}", :info, tag: 'MetadataIngestService')
      Rails.logger.info("[MetadataIngestService] Fetching metadata for IDs: #{batch_ids.first(25).join(', ')}...")
      res = HTTParty.get("#{base_url}#{query_params}")

      if res.code != 200
        Rails.logger.error("[batch_retrieve_and_process_metadata] Failed to fetch for IDs: #{batch_ids.first(25).join(', ')}:" \
        "#{res.code} - #{res.message}")
      end

      xml_doc = Nokogiri::XML(res.body)
      handle_pmc_errors(xml_doc) if db == 'pmc' && xml_doc.xpath('//pmc-articleset/error').any?
      handle_pubmed_errors(xml_doc, batch_ids) if db == 'pubmed'

      current_batch = xml_doc.xpath(db == 'pubmed' ? '//PubmedArticle' : '//article')
      current_batch, non_unc_records = generate_filtered_batch(current_batch, db: db)
      log_non_unc_records(non_unc_records, db)
      process_batch(current_batch)

      batch_count += 1
      # Respect NCBI rate limits
      sleep(0.34)
    end

    # Flush any remaining write buffer to file
    flush_buffer_to_file unless @write_buffer.empty?
    LogUtilsHelper.double_log("Completed batch retrieval and processing for #{db}.", :info, tag: 'MetadataIngestService')
  end

  private

  # Handles PMC errors by logging them and moving the alternate IDs to a file to retry later.
  def handle_pmc_errors(xml_doc)
    xml_doc.xpath('//pmc-articleset/error').each do |err|
      pmcid = err['pmcid']
      Rails.logger.warn("[MetadataIngestService] PMC error for #{pmcid}: #{err.text}")
      move_to_pubmed_alternate_ids_file(retrieve_alternate_ids_for_doc(err))
    end
  end

  def move_to_pubmed_alternate_ids_file(alternate_ids)
    return if alternate_ids.nil? || alternate_ids.empty?

    begin
      File.open(File.join(@output_dir, 'pubmed_alternate_ids.jsonl'), 'a') do |file|
        file.puts(alternate_ids)
      end
      LogUtilsHelper.double_log("Moved alternate IDs to pubmed_alternate_ids.jsonl: #{alternate_ids}", :info, tag: 'MetadataIngestService')
      rescue => e
        LogUtilsHelper.double_log("Error writing to pubmed_alternate_ids.jsonl: #{e.message}", :error, tag: 'MetadataIngestService')
        Rails.logger.error("Backtrace: #{e.backtrace.join("\n")}")
    end
  end


  # Efetch doesn't return metadata for ids which have errors. Retrieve the ids that were returned and log the missing ones as failed.
  def handle_pubmed_errors(xml_doc, ids)
    returned_ids = xml_doc.xpath('//PubmedArticle').map do |article|
      article.at_xpath('.//PMID')&.text
    end.compact.to_set

    missing_ids = ids.reject { |id| returned_ids.include?(id) }

    unless missing_ids.empty?
      LogUtilsHelper.double_log("PubMed EFetch missing #{missing_ids.size} of #{ids.size} IDs: #{missing_ids.first(10)}...", :warn, tag: 'MetadataIngestService')
      missing_ids.each do |missing_id|
        record_result(
            category: :failed,
            message: 'EFetch: PubMed record not found',
            ids: { pmid: missing_id }
        )
      end
    end
  end

  def process_batch(batch)
    batch.each do |doc|
      alternate_ids = { 'pmid' => nil, 'pmcid' => nil, 'doi' => nil}
      begin
        alternate_ids = retrieve_alternate_ids_for_doc(doc)
        match = find_best_work_match(alternate_ids)
        # Skip if work with these IDs already exists
        if match&.dig(:work_id).present?
          Rails.logger.info("[MetadataIngestService] Work with IDs #{alternate_ids.inspect} already exists: #{match[:work_id]}")
          record_result(
              category: :skipped,
              ids: alternate_ids,
              message: 'Filtered after retrieving metadata: work exists',
              article: WorkUtilsHelper.fetch_model_instance(match[:work_type], match[:work_id])
          )
          next
        end

        # If no match found, create a new article
        Rails.logger.info("[MetadataIngestService] No existing work found for IDs: #{alternate_ids.inspect}. Creating new article.")
        article = new_article(doc)
        article.save!
        record_result(
            category: :successfully_ingested_metadata_only,
            ids: alternate_ids,
            article: article
        )
    rescue => e
      Rails.logger.error("[MetadataIngestService] Error processing record: #{alternate_ids.inspect}, Error: #{e.message}")
      Rails.logger.error("Backtrace: #{e.backtrace.join("\n")}")
      article.destroy if article&.persisted?
      record_result(
          category: :failed,
          message: "#{e.message}",
          ids: alternate_ids
      )
      end
    end
  end

  def retrieve_alternate_ids_for_doc(doc)
    begin
      if is_pubmed?(doc)
        pmid = doc.at_xpath('PubmedData/ArticleIdList/ArticleId[@IdType="pubmed"]')&.text
        pmcid = doc.at_xpath('PubmedData/ArticleIdList/ArticleId[@IdType="pmc"]')&.text
      else
        pmid = doc.at_xpath('.//article-id[@pub-id-type="pmid"]')&.text
        pmcid = doc.at_xpath('.//article-id[@pub-id-type="pmcid"]')&.text
      end
      @record_ids.find { |row| row['pmid'] == pmid || row['pmcid'] == pmcid }
    rescue => e
      Rails.logger.error("[MetadataIngestService] Error retrieving alternate IDs for document: #{e.message}")
      Rails.logger.error("Backtrace: #{e.backtrace.join("\n")}")
      puts "Error retrieving alternate IDs for document: #{e.message}"
      puts "Backtrace: #{e.backtrace.join("\n")}"
      nil
    end
  end

  def new_article(metadata)
    Rails.logger.debug('[MetadataIngestService] Initializing new article object')
    article = Article.new
    article.visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
    builder = attribute_builder(metadata, article)
    builder.populate_article_metadata
    article
  end


  def is_pubmed?(metadata)
    metadata.name == 'PubmedArticle'
  end

  def attribute_builder(metadata, article)
    is_pubmed?(metadata) ?
    Tasks::PubmedIngest::SharedUtilities::AttributeBuilders::PubmedAttributeBuilder.new(metadata, article, @admin_set, @config['depositor_onyen']) :
    Tasks::PubmedIngest::SharedUtilities::AttributeBuilders::PmcAttributeBuilder.new(metadata, article, @admin_set, @config['depositor_onyen'])
  end

  def record_result(category:, message: '', ids: {}, article: nil)
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

  def find_best_work_match(alternate_ids)
    # ensures string keys
    alt_ids = alternate_ids.transform_keys(&:to_s)
    ['doi', 'pmcid', 'pmid'].each do |key|
      id = alt_ids[key]
      next if id.blank?

      work_data = key == :doi ?
        WorkUtilsHelper.fetch_work_data_by_doi(id) :
        WorkUtilsHelper.fetch_work_data_by_alternate_identifier(id)


      work_data = WorkUtilsHelper.fetch_work_data_by_alternate_identifier(id)
      return work_data if work_data.present?
    end
    nil
  end

  def pubmed_xml_has_unc_affiliation?(nokogiri_doc)
    aff_nodes = nokogiri_doc.xpath('.//AffiliationInfo/Affiliation')
    aff_nodes.any? { |n| AffiliationUtilsHelper.is_unc_affiliation?(n.text) }
  end

  def pmc_xml_has_unc_affiliation?(nokogiri_doc)
    aff_nodes = nokogiri_doc.xpath('.//aff | .//contrib//aff | .//contrib-group//aff')
    aff_nodes.any? { |n| AffiliationUtilsHelper.is_unc_affiliation?(n.text) }
  end

  # Extracts a filtered batch of records that have UNC affiliations
  # Despite filters defined while retrieving IDs, this ensures we only process records with UNC affiliations.
  # The API otherwise may return records without any affiliation or with affiliations that do not match our criteria.
  def generate_filtered_batch(batch, db:)
    # Partition into UNC-affiliated and non-UNC-affiliated
    filtered_batch, non_unc = batch.partition do |doc|
      db == 'pubmed' ? pubmed_xml_has_unc_affiliation?(doc) : pmc_xml_has_unc_affiliation?(doc)
    end

    LogUtilsHelper.double_log(
      "Filtered out #{non_unc.size} #{db} records with no UNC affiliation; #{filtered_batch.size} remain.",
      :info,
      tag: 'MetadataIngestService'
    )

    # Return both arrays
    [filtered_batch, non_unc]
  end

  def log_non_unc_records(non_unc_records, db)
    return if non_unc_records.empty?
    begin
      non_unc_records.each do |doc|
        alternate_ids = retrieve_alternate_ids_for_doc(doc) || { 'pmid' => nil, 'pmcid' => nil, 'doi' => nil }
        record_result(
          category: :skipped_non_unc_affiliation,
          message: 'N/A',
          ids: alternate_ids
        )
      end

      LogUtilsHelper.double_log(
        "Logged #{non_unc_records.size} #{db} records filtered out due to no UNC affiliation.",
        :info,
        tag: 'MetadataIngestService'
      )
    rescue => e
      LogUtilsHelper.double_log("Error logging non-UNC records: #{e.message}", :error, tag: 'MetadataIngestService')
      Rails.logger.error("Backtrace: #{e.backtrace.join("\n")}")
    end
  end
end
