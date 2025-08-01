# frozen_string_literal: true
class Tasks::PubmedIngest::Recurring::Utilities::IdRetrievalService
  def initialize(start_date:, end_date:, tracker:)
    @start_date = start_date
    @end_date = end_date
    @tracker = tracker
  end

  def retrieve_ids_within_date_range(output_path:, db:, retmax: 1000)
    # Rails.logger.info("[retrieve_ids_within_date_range] Fetching IDs within date range: #{@start_date.strftime('%Y-%m-%d')} - #{@end_date.strftime('%Y-%m-%d')} for #{db} database")
    LogUtilsHelper.double_log("Fetching IDs within date range: #{@start_date.strftime('%Y-%m-%d')} - #{@end_date.strftime('%Y-%m-%d')} for #{db} database", :info, tag: 'retrieve_ids_within_date_range')
    base_url = 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi'
    count = 0
    # Initialize cursor from tracker or set to 0
    job_progress = @tracker['progress']['retrieve_ids_within_date_range'][db]
    cursor = job_progress['cursor']
    params = {
      retmax: retmax,
      db: db,
      term: "#{@start_date.strftime('%Y/%m/%d')}:#{@end_date.strftime('%Y/%m/%d')}[PDAT]"
    }
    File.open(output_path, 'a') do |file|
      loop do
        break if cursor > 200 # WIP: Remove in production
        res = HTTParty.get(base_url, query: params.merge({ retstart: cursor }))
        puts "Response code: #{res.code}, message: #{res.message}, URL: #{base_url}?#{params.merge({ retstart: cursor }).to_query}"
        if res.code != 200
          # Rails.logger.error("[retrieve_ids_within_date_range] Failed to retrieve IDs: #{res.code} - #{res.message}")
          LogUtilsHelper.double_log("Failed to retrieve IDs: #{res.code} - #{res.message}", :error, tag: 'retrieve_ids_within_date_range')
          break
        end
        parsed_response = Nokogiri::XML(res.body)
        # Extract IDs from the response
        raw_ids = parsed_response.xpath('//IdList/Id').map(&:text).compact
        ids =  if db == 'pmc'
                #  PMC IDs are prefixed with 'PMC'
                 raw_ids.map { |id| "PMC#{id}" }
                else
                  raw_ids
                end
        # Assign indexes to the IDs
        ids_with_indexes = ids.map.with_index { |id, index|
          {'index' => index + cursor, 'id' => id  }
        }
        begin
          ids_with_indexes.each do |entry|
            file.puts(JSON.generate(entry))
          end
          count += ids_with_indexes.size
          cursor += retmax
          job_progress['cursor'] = cursor
          @tracker.save
        rescue => e
          Rails.logger.error("Failed to write or save tracker: #{e.message}")
          raise e
        end
        break if cursor > parsed_response.xpath('//Count').text.to_i
      end
    end
    # Rails.logger.info("[retrieve_ids_within_date_range] Retrieved #{count} IDs from #{db} database")
    LogUtilsHelper.double_log("Retrieved #{count} IDs from #{db} database", :info, tag: 'retrieve_ids_within_date_range')
  end

  def stream_and_write_alternate_ids(input_path:, output_path:, db:, batch_size: 200)
    # Rails.logger.info("[stream_and_write_alternate_ids] Streaming and writing alternate IDs from #{input_path} to #{output_path}")
    buffer = []
    job_progress = @tracker['progress']['stream_and_write_alternate_ids'][db]
    last_cursor = job_progress['cursor']
    LogUtilsHelper.double_log("Streaming and writing alternate IDs from #{input_path} to #{output_path} for #{db} database", :info, tag: 'stream_and_write_alternate_ids')
    LogUtilsHelper.double_log("Last cursor position: #{last_cursor}", :info, tag: 'stream_and_write_alternate_ids')

    File.open(output_path, 'w') do |output_file|
      File.foreach(input_path) do |line|
        identifier_hash = JSON.parse(line.strip)
        identifier = identifier_hash['id']
        if identifier_hash['index'] < last_cursor
          # Skip IDs that are before the last cursor position
          next
        end
        buffer << identifier
        if buffer.size >= batch_size
          write_batch_alternate_ids(ids: buffer, db: db, output_file: output_file)
          # Save after batch write
          job_progress['cursor'] += buffer.size
          @tracker.save
          last_cursor = job_progress['cursor']
          buffer.clear
        end
      end
      unless buffer.empty?
        write_batch_alternate_ids(ids: buffer, db: db, output_file: output_file)
        # Update tracker progress, clear buffer and increment cursor
        job_progress['cursor'] += buffer.size
        @tracker.save
      end
    end
    # Rails.logger.info("[stream_and_write_alternate_ids] Finished writing alternate IDs to #{output_path} for #{db} database")
    LogUtilsHelper.double_log("Finished writing alternate IDs to #{output_path} for #{db} database", :info, tag: 'stream_and_write_alternate_ids')
  end

  def write_batch_alternate_ids(ids:, db:, output_file:)
    base_url = 'https://www.ncbi.nlm.nih.gov/pmc/utils/idconv/v1.0/'
    query_string = "ids=#{ids.join(',')}&tool=CDR&email=cdr@unc.edu&retmode=xml"
    full_url = "#{base_url}?#{query_string}"

    res = HTTParty.get(full_url)
    Rails.logger.debug("Response code: #{res.code}, message: #{res.message}, URL: #{full_url}")

    xml = Nokogiri::XML(res.body)
    xml.xpath('//record').each do |record|
      alternate_ids = if record['status'] == 'error'
                        Rails.logger.debug("[IdRetrievalService] Error for ID: #{record['id']}, status: #{record['status']}")
                        {
                          'pmid' => record['pmid'],
                          'pmcid' => record['pmcid'],
                          'doi' => record['doi'],
                          'error' => record['status'],
                          'cdr_url' => generate_cdr_url_for_pubmed_identifier(id_hash: { 'pmid' => record['pmid'] }),
                        }
      else
        {
          'pmid' => record['pmid'],
          'pmcid' => record['pmcid'],
          'doi' => record['doi'],
          'cdr_url' => generate_cdr_url_for_pubmed_identifier(id_hash: { 'pmid' => record['pmid'], 'pmcid' => record['pmcid'] }),
        }
      end

      output_file.puts(alternate_ids.to_json) if alternate_ids.values.any?(&:present?)
    end
  rescue StandardError => e
    LogUtilsHelper.double_log("Error converting IDs: #{e.message}", :error, tag: 'write_batch_alternate_ids')
    LogUtilsHelper.double_log(e.backtrace.join("\n"), :error, tag: 'write_batch_alternate_ids')
  end

  def generate_cdr_url_for_pubmed_identifier(id_hash:)
    identifier = id_hash['pmcid'] || id_hash['pmid']
    raise ArgumentError, 'No identifier (PMCID or PMID) found in row' unless identifier.present?

    result = Hyrax::SolrService.get(
      "identifier_tesim:\"#{identifier}\"",
      rows: 1,
      fl: 'id,title_tesim,has_model_ssim,file_set_ids_ssim'
    )['response']['docs']

    raise "No Solr record found for identifier: #{identifier}" if result.empty?

    record = result.first
    raise "Missing `has_model_ssim` in Solr record: #{record.inspect}" unless record['has_model_ssim']&.first.present?

    model = record['has_model_ssim']&.first&.underscore&.pluralize || 'works'
    URI.join(ENV['HYRAX_HOST'], "/concern/#{model}/#{record['id']}").to_s
  rescue => e
    Rails.logger.warn("[generate_cdr_url_for_pubmed_identifier] Failed for identifier: #{identifier}, error: #{e.message}")
    nil
  end

  def adjust_id_lists(pubmed_path:, pmc_path:)
    return if adjustment_already_completed?

    log_adjustment_start(pubmed_path, pmc_path)

    pubmed_records = read_jsonl(pubmed_path)
    pmc_records    = read_jsonl(pmc_path)

    original_sizes = {
      pubmed: pubmed_records.size,
      pmc: pmc_records.size
    }

    deduped_pmc, seen_keys = deduplicate_pmc_records(pmc_records)
    deduped_pubmed         = deduplicate_pubmed_records(pubmed_records, seen_keys)

    write_deduped_records(pmc_path, deduped_pmc)
    write_deduped_records(pubmed_path, deduped_pubmed)

    update_tracker_with_adjustment_stats(original_sizes, deduped_pubmed.size, deduped_pmc.size)

    log_adjustment_summary(original_sizes, deduped_pubmed.size, deduped_pmc.size)
  end


  private

  def adjustment_already_completed?
    if @tracker['progress']['adjust_id_lists']['completed']
      LogUtilsHelper.double_log('ID lists already adjusted. Skipping adjustment step.', :info, tag: 'adjust_id_lists')
      true
    else
      false
    end
  end

  def log_adjustment_start(pubmed_path, pmc_path)
    LogUtilsHelper.double_log('Adjusting ID lists in memory for PubMed and PMC databases', :info, tag: 'adjust_id_lists')
    LogUtilsHelper.double_log("PubMed path: #{pubmed_path}, PMC path: #{pmc_path}", :info, tag: 'adjust_id_lists')
  end

  def log_adjustment_summary(original_sizes, adjusted_pubmed_size, adjusted_pmc_size)
    LogUtilsHelper.double_log("Adjusted ID lists - PubMed: #{original_sizes[:pubmed]} ➝ #{adjusted_pubmed_size}, PMC: #{original_sizes[:pmc]} ➝ #{adjusted_pmc_size}", :info, tag: 'adjust_id_lists')
  end

  def read_jsonl(path)
    File.readlines(path).map { |line| JSON.parse(line) }
  end

  def write_deduped_records(path, records)
    File.open(path, 'w') do |f|
      records.each_with_index do |record, i|
        record['index'] = i
        f.puts(record.to_json)
      end
    end
  end

  def dedup_key(record)
    record['doi'].presence || record['pmcid'].presence || record['pmid']
  end

  def deduplicate_pmc_records(records)
    seen_keys = Set.new
    deduped = records.each_with_object([]) do |record, acc|
      next if record['pmcid'].blank?

      key = dedup_key(record)
      next if key.blank? || seen_keys.include?(key)

      seen_keys << key
      acc << record
    end
    [deduped, seen_keys]
  end

  def deduplicate_pubmed_records(records, seen_keys)
    records.each_with_object([]) do |record, acc|
      key = dedup_key(record)
      next if key.blank? || seen_keys.include?(key)

      seen_keys << key
      acc << record
    end
  end

  def update_tracker_with_adjustment_stats(original_sizes, pubmed_new_size, pmc_new_size)
    @tracker['progress']['adjust_id_lists']['completed'] = true
    @tracker['progress']['adjust_id_lists']['pubmed']['original_size']  = original_sizes[:pubmed]
    @tracker['progress']['adjust_id_lists']['pubmed']['adjusted_size']  = pubmed_new_size
    @tracker['progress']['adjust_id_lists']['pmc']['original_size']     = original_sizes[:pmc]
    @tracker['progress']['adjust_id_lists']['pmc']['adjusted_size']     = pmc_new_size
    @tracker.save
  end

end
