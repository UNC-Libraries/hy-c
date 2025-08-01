# frozen_string_literal: true
class Tasks::PubmedIngest::Recurring::Utilities::MetadataIngestService
  def initialize(config:, results:, tracker:, results_path:)
    @config = config
    @output_dir = config['output_dir']
    @record_ids = nil
    @results_path = results_path
    @admin_set = AdminSet.where(title: @config['admin_set_title']).first
    @results = results
    @tracker = tracker
    @write_buffer = []
    @flush_threshold = 200
  end

  def load_alternate_ids_from_file(path:, db:)
    LogUtilsHelper.double_log("Loading IDs from file with alt ids: #{path}", :info, tag: 'MetadataIngestService')
    cursor = @tracker['progress']['metadata_ingest'][db]['cursor']
    filtered_ids = []
    count = 0

    LogUtilsHelper.double_log("Resuming from cursor: #{cursor} out of #{File.foreach(path).count} records for the #{db} database.", :info, tag: 'MetadataIngestService')
    File.foreach(path) do |line|
      record = JSON.parse(line.strip)
      count += 1
      # Skip records before the cursor, for resuming
      next if record['index'] < cursor

      # Skip existing works
      match = find_best_work_match(record.slice('pmid', 'pmcid', 'doi'))
      if match.present?
        Rails.logger.info("[MetadataIngestService] Skipping #{record.inspect} — work already exists.")
        article = WorkUtilsHelper.fetch_model_instance(match[:work_type], match[:work_id])
        record_result(category: :skipped, message: 'Pre-filtered: work exists', ids: record, article: article)
        next
      end

      filtered_ids << record
    end

    @record_ids = filtered_ids
    LogUtilsHelper.double_log("Loaded #{@record_ids.size} remaining IDs from alternate IDs file with #{count} total records.", :info, tag: 'MetadataIngestService')
  end


  def batch_retrieve_and_process_metadata(batch_size: 100, db:)
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
      process_batch(current_batch, db)

      # Update tracker cursor after processing batch
      last_index = batch.last['index']
      @tracker['progress']['metadata_ingest'][db]['cursor'] = last_index + 1
      @tracker.save
      batch_count += 1
        #Respect NCBI rate limits
      sleep(0.34)
    end

    # Flush any remaining write buffer to file
    flush_buffer_to_file unless @write_buffer.empty?
    # Rails.logger.info("[batch_retrieve_and_process_metadata] Completed processing #{@record_ids.size} #{db} records.")
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
      # Rails.logger.info("[MetadataIngestService] Moved #{alternate_ids.size} alternate IDs" \
      #                     'to pubmed_alternate_ids.jsonl')
      LogUtilsHelper.double_log("Moved alternate IDs to pubmed_alternate_ids.jsonl: #{alternate_ids}", :info, tag: 'MetadataIngestService')
      rescue => e
        # Rails.logger.error("[MetadataIngestService] Error writing to pubmed_alternate_ids.jsonl: #{e.message}")
        LogUtilsHelper.double_log("Error writing to pubmed_alternate_ids.jsonl: #{e.message}", :error, tag: 'MetadataIngestService')
        Rails.logger.error("Backtrace: #{e.backtrace.join("\n")}")
    end
  end


  # efetch doesn't return metadata for ids which have errors, handling it differently
  def handle_pubmed_errors(xml_doc, ids)
    returned_ids = xml_doc.xpath('//PubmedArticle').map do |article|
      article.at_xpath('.//PMID')&.text
    end.compact.to_set

    missing_ids = ids.reject { |id| returned_ids.include?(id) }

    unless missing_ids.empty?
      # Rails.logger.warn("[MetadataIngestService] PubMed EFetch missing #{missing_ids.size} of #{ids.size} IDs: #{missing_ids.first(10)}...")
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

  def process_batch(batch, db)
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
        # @result_tracker[:successfully_ingested] << {
        #     ids: {
        #         pmid: alternate_ids['pmid'],
        #         pmcid: alternate_ids['pmcid'],
        #         doi: alternate_ids['doi']
        #     },
        #     article: article
        # }
        # @result_tracker[:counts][:successfully_attached] += 1
        record_result(
            category: :successfully_ingested,
            ids: alternate_ids,
            article: article
        )
    rescue => e
      Rails.logger.error("[MetadataIngestService] Error processing record: #{alternate_ids.inspect}, Error: #{e.message}")
      Rails.logger.error("Backtrace: #{e.backtrace.join("\n")}")
      article.destroy if article&.persisted?
    #   @result_tracker[:failed] << {
    #       ids: alternate_ids,
    #       message: e.message
    #   }
    #   @result_tracker[:counts][:failed] += 1
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
  end


  def is_pubmed?(metadata)
    metadata.name == 'PubmedArticle'
  end

  def attribute_builder(metadata, article)
    is_pubmed?(metadata) ?
    Tasks::PubmedIngest::SharedUtilities::AttributeBuilders::PubmedAttributeBuilder.new(metadata, article, @admin_set, @config['depositor_onyen']) :
    Tasks::PubmedIngest::SharedUtilities::AttributeBuilders::PmcAttributeBuilder.new(metadata, article, @admin_set, @config['depositor_onyen'])
  end


  def save_results_json(path:)
    LogUtilsHelper.double_log("Updating results JSON at #{path}", :info, tag: 'MetadataIngestService')
    File.open(path, 'w') do |file|
      file.puts(JSON.pretty_generate(@results))
    end
    LogUtilsHelper.double_log('Results JSON updated successfully.', :info, tag: 'MetadataIngestService')
  rescue => e
    LogUtilsHelper.double_log("Failed to update results JSON: #{e.message}", :error, tag: 'MetadataIngestService')
    Rails.logger.info("Backtrace: #{e.backtrace.join("\n")}")
  end


  def record_result_deprecated(category:, message:, ids: {}, article: nil)
    row = {
    'pdf_attached' => message,
    'pmid' => ids['pmid'],
    'pmcid' => ids['pmcid'],
    'doi' => ids['doi'],
    }
    if article
      row['article'] = article
      row['cdr_url'] = generate_cdr_url_for_article(article)
    end
    @results[:counts][category] += 1
    @results[category] << row
  end

  def record_result(category:, message: '', ids: {}, article: nil)
    # Merge article id into ids if article is provided
    log_entry = {
        ids: {
          pmid: ids['pmid'],
          pmcid: ids['pmcid'],
          doi: ids['doi'],
          article_id: article&.id
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
    File.open(@results_path, 'a') do |file|
      @write_buffer.each { |entry| file.puts(JSON.generate(entry)) }
    end
    LogUtilsHelper.double_log("Flushed #{@write_buffer.size} entries to #{@results_path}", :info, tag: 'MetadataIngestService')
    @write_buffer.clear
    rescue => e
      LogUtilsHelper.double_log("Failed to flush buffer to file: #{e.message}", :error, tag: 'MetadataIngestService')
      Rails.logger.error("Backtrace: #{e.backtrace.join("\n")}")
  end

  def generate_cdr_url_for_article(article)
    "#{ENV['HYRAX_HOST']}#{Rails.application.routes.url_helpers.hyrax_article_path(article, host: ENV['HYRAX_HOST'])}"
  end

  def find_best_work_match(alternate_ids)
    # ensures string keys
     alt_ids = alternate_ids.transform_keys(&:to_s)  
    ['doi', 'pmcid', 'pmid'].each do |key|
      id = alt_ids[key]
      next if id.blank?

      work_data = WorkUtilsHelper.fetch_work_data_by_alternate_identifier(id)
      return work_data if work_data.present?
    end
    nil
  end
end
