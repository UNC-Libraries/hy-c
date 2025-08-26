# frozen_string_literal: true
require_dependency 'affiliation_utils_helper'

class Tasks::PubmedIngest::Recurring::Utilities::IdRetrievalService
  UNC_AFFILIATION_TERMS = ::AffiliationUtilsHelper::UNC_AFFILIATION_TERMS
  def initialize(start_date:, end_date:, tracker:)
    @start_date = start_date
    @end_date = end_date
    @tracker = tracker
  end

  def retrieve_ids_within_date_range(output_path:, db:, retmax: 200, extras: nil)
    LogUtilsHelper.double_log("Fetching IDs within date range: #{@start_date.strftime('%Y-%m-%d')} - #{@end_date.strftime('%Y-%m-%d')} for #{db} database", :info, tag: 'retrieve_ids_within_date_range')
    base_url = 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi'
    count = 0
    # Initialize cursor from tracker or set to 0
    job_progress = @tracker['progress']['retrieve_ids_within_date_range'][db]
    cursor = job_progress['cursor']
    term_str = build_search_terms(
      db: db,
      start_date: @start_date,
      end_date:   @end_date,
      extras: extras
    )
    params = {
      db: db,
      term: term_str,
      retmax: retmax,
      retmode: 'xml',
      tool: 'CDR',
      email: 'cdr@unc.edu'
    }
    File.open(output_path, 'a') do |file|
      loop do
        res = HTTParty.get(base_url, query: params.merge({ retstart: cursor }))
        Rails.logger.debug("Response code: #{res.code}, message: #{res.message}, URL: #{base_url}?#{params.merge({ retstart: cursor }).to_query}")
        if res.code != 200
          Rails.logger.error("Failed to retrieve IDs: #{res.code} - #{res.message}")
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
        # Write IDs to file
        begin
          ids.each do |id|
            file.puts({ 'id' => id }.to_json)
          end
          count += ids.size
          cursor += retmax
          job_progress['cursor'] = cursor
          @tracker.save
        rescue => e
          Rails.logger.error("Failed to write or save tracker: #{e.message}")
          raise e
        end
        break if cursor > parsed_response.xpath('//Count').text.to_i

        # Respect NCBI rate limits
        sleep(0.34)
      end
    end
    Rails.logger.info("Retrieved #{count} IDs from #{db} database")
  end

  def stream_and_write_alternate_ids(input_path:, output_path:, db:, batch_size: 200)
    buffer = []
    job_progress = @tracker['progress']['stream_and_write_alternate_ids'][db]
    last_cursor = job_progress['cursor']
    LogUtilsHelper.double_log("Streaming and writing alternate IDs from #{input_path} to #{output_path} for #{db} database", :info, tag: 'stream_and_write_alternate_ids')
    LogUtilsHelper.double_log("Last cursor position: #{last_cursor}", :info, tag: 'stream_and_write_alternate_ids')

    File.open(output_path, 'w') do |output_file|
      line_index = 0
      File.foreach(input_path) do |line|
        if line_index < last_cursor
          line_index += 1
          next
        end

        identifier_hash = JSON.parse(line.strip)
        identifier = identifier_hash['id']
        line_index += 1
        buffer << identifier
        if buffer.size >= batch_size
          write_batch_alternate_ids(ids: buffer.dup, db: db, output_file: output_file)
          # Save after batch write
          job_progress['cursor'] = line_index
          @tracker.save
          last_cursor = job_progress['cursor']
          buffer.clear
        end
      end
      unless buffer.empty?
        write_batch_alternate_ids(ids: buffer, db: db, output_file: output_file)
        # Update tracker progress, clear buffer and increment cursor
        job_progress['cursor'] = line_index
        @tracker.save
      end
    end
    LogUtilsHelper.double_log("Finished writing alternate IDs to #{output_path} for #{db} database", :info, tag: 'stream_and_write_alternate_ids')
  end

  def write_batch_alternate_ids(ids:, db:, output_file:)
    base_url = 'https://www.ncbi.nlm.nih.gov/pmc/utils/idconv/v1.0/'
    query_string = "ids=#{ids.join(',')}&tool=CDR&email=cdr@unc.edu&retmode=xml"
    full_url = "#{base_url}?#{query_string}"

    res = HTTParty.get(full_url)
    Rails.logger.debug("Response code: #{res.code}, URL: #{full_url}")

    xml = Nokogiri::XML(res.body)
    xml.xpath('//record').each do |record|
      alternate_ids = if record['status'] == 'error'
                        Rails.logger.debug("[IdRetrievalService] Error for ID: #{record['id']}, status: #{record['status']}")
                        {
                          'pmid' => record['pmid'],
                          'pmcid' => record['pmcid'],
                          'doi' => record['doi'],
                          'error' => record['status'],
                          'cdr_url' => WorkUtilsHelper.generate_cdr_url_for_alternate_id(record['pmcid'] || record['pmid'])
                        }
      else
        {
          'pmid' => record['pmid'],
          'pmcid' => record['pmcid'],
          'doi' => record['doi'],
          'cdr_url' => WorkUtilsHelper.generate_cdr_url_for_alternate_id(record['pmcid'] || record['pmid'])
        }
      end

      output_file.puts(alternate_ids.to_json) if alternate_ids.values.any?(&:present?)
    end
  rescue StandardError => e
    LogUtilsHelper.double_log("Error converting IDs: #{e.message}", :error, tag: 'write_batch_alternate_ids')
    LogUtilsHelper.double_log(e.backtrace.join("\n"), :error, tag: 'write_batch_alternate_ids')
  end

  def adjust_id_lists(pubmed_path:, pmc_path:)
    return if adjustment_already_completed?

    log_adjustment_start(pubmed_path, pmc_path)

    pubmed_records = JsonFileUtilsHelper.read_jsonl(pubmed_path, symbolize_names: true)
    pmc_records    = JsonFileUtilsHelper.read_jsonl(pmc_path, symbolize_names: true)

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

  def write_deduped_records(path, records)
    File.open(path, 'w') do |f|
      records.each_with_index do |record, i|
        record['index'] = i
        f.puts(record.to_json)
      end
    end
  end

  def dedup_key(record)
    record[:doi].presence || record[:pmcid].presence || record[:pmid].presence
  end

  def deduplicate_pmc_records(records)
    seen_keys = Set.new
    deduped = records.each_with_object([]) do |record, acc|
      next if record[:pmcid].blank?

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

  def build_search_terms(db:, start_date:, end_date:, extras: nil)
    if db == 'pubmed'
      build_pubmed_term(
        start_date: start_date,
        end_date:   end_date,
        extras: extras
      )
    else
      # Keep PMC as-is (no affiliation filter support)
      "#{start_date.strftime('%Y/%m/%d')}:#{end_date.strftime('%Y/%m/%d')}[PDAT]"
    end
  end


  # Build a PubMed term with date range + optional UNC affiliation + extras
  def build_pubmed_term(start_date:, end_date:, extras: nil)
    date = "#{start_date.strftime('%Y/%m/%d')}:#{end_date.strftime('%Y/%m/%d')}[PDAT]"

    aff = '(' + UNC_AFFILIATION_TERMS.map { |t| %Q{"#{t}"[AD]} }.join(' OR ') + ')'

    [aff, date, extras].compact.join(' AND ')
  end
end
