# frozen_string_literal: true
class Tasks::PubmedIngest::Recurring::Utilities::IdRetrievalService
  def initialize(start_date:, end_date:)
    @start_date = start_date
    @end_date = end_date
  end

  def retrieve_ids_within_date_range(output_path:, db:, retmax: 1000)
    Rails.logger.info("[retrieve_ids_within_date_range] Fetching IDs within date range: #{@start_date.strftime('%Y-%m-%d')} - #{@end_date.strftime('%Y-%m-%d')} for #{db} database")
    base_url = 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi'
    count = 0
    cursor = 0
    params = {
      retmax: retmax,
      db: db,
      term: "#{@start_date.strftime('%Y/%m/%d')}:#{@end_date.strftime('%Y/%m/%d')}[PDAT]"
    }
    File.open(output_path, 'a') do |file|
      loop do
        break if cursor > 2000 # WIP: Remove in production
        res = HTTParty.get(base_url, query: params.merge({ retstart: cursor }))
        puts "Response code: #{res.code}, message: #{res.message}, URL: #{base_url}?#{params.merge({ retstart: cursor }).to_query}"
        if res.code != 200
          Rails.logger.error("[retrieve_ids_within_date_range] Failed to retrieve IDs: #{res.code} - #{res.message}")
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
        file.puts(ids.join("\n"))
        count += ids.size
        cursor += retmax
        break if cursor > parsed_response.xpath('//Count').text.to_i
      end
    end
    Rails.logger.info("[retrieve_ids_within_date_range] Retrieved #{count} IDs from #{db} database")
  end

  def stream_and_write_alternate_ids(input_path:, output_path:, db:, batch_size: 200)
    Rails.logger.info("[stream_and_write_alternate_ids] Streaming and writing alternate IDs from #{input_path} to #{output_path}")
    buffer = []
    File.open(output_path, 'w') do |output_file|
      File.foreach(input_path) do |line|
        identifier = line.strip
        buffer << identifier
        if buffer.size >= batch_size
          write_batch_alternate_ids(ids: buffer, db: db, output_file: output_file)
          buffer.clear
        end
      end
      write_batch_alternate_ids(ids: buffer, db: db, output_file: output_file) unless buffer.empty?
    end
    Rails.logger.info("[stream_and_write_alternate_ids] Finished writing alternate IDs to #{output_path} for #{db} database")
  end

  def write_batch_alternate_ids(ids:, db:, output_file:)
    base_url = 'https://www.ncbi.nlm.nih.gov/pmc/utils/idconv/v1.0/'
    query_string = "ids=#{ids.join(',')}&tool=CDR&email=cdr@unc.edu&retmode=xml"
    full_url = "#{base_url}?#{query_string}"

    res = HTTParty.get(full_url)
    Rails.logger.debug("Response code: #{res.code}, message: #{res.message}, URL: #{full_url}")
    puts "Response code: #{res.code}, Response message: #{res.message}, URL: #{full_url}"

    xml = Nokogiri::XML(res.body)
    xml.xpath('//record').each do |record|
      puts "Processing record: #{record['id']}, status: #{record['status']}, pmid: #{record['pmid']}, pmcid: #{record['pmcid']}, doi: #{record['doi']}"
      alternate_ids = if record['status'] == 'error'
                        Rails.logger.debug("[IdRetrievalService] Error for ID: #{record['id']}, status: #{record['status']}")
                        {
                          'pmid' => record['pmid'],
                          'pmcid' => record['pmcid'],
                          'doi' => record['doi'],
                          'error' => record['status'],
                          'cdr_url' => generate_cdr_url_for_pubmed_identifier(id_hash: { 'pmid' => record['pmid'] })
                        }
      else
        {
          'pmid' => record['pmid'],
          'pmcid' => record['pmcid'],
          'doi' => record['doi'],
          'cdr_url' => generate_cdr_url_for_pubmed_identifier(id_hash: { 'pmid' => record['pmid'], 'pmcid' => record['pmcid'] })
        }
      end
      puts "Alternate IDs for #{record['id']}: #{alternate_ids.inspect}"
      output_file.puts(alternate_ids.to_json) if alternate_ids.values.any?(&:present?)
    end
  rescue StandardError => e
    Rails.logger.error("[IdRetrievalService] Error converting IDs: #{e.message}")
    Rails.logger.error e.backtrace.join("\n")
    puts "Error converting IDs: #{e.message}"
    puts e.backtrace.join("\n")
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
    # Load and parse records, sizes
    pubmed_records = File.readlines(pubmed_path).map { |line| JSON.parse(line) }
    pmc_records = File.readlines(pmc_path).map { |line| JSON.parse(line) }
    original_pubmed_record_size = pubmed_records.size
    original_pmc_record_size = pmc_records.size

    # Set of known PMCIDs
    pmc_ids_seen = Set.new(pmc_records.map { |rec| rec['pmcid'] }.compact)

    # If any records in the PMCID set only have PMIDs, move it to the pubmed records
    new_pubmed_records = pmc_records.select { |r| r['pmcid'].blank? }

    # Move PubMed records with a unique PMCID into the PMC set
    new_pmc_records, remaining_pubmed_records = pubmed_records.partition do |record|
      pmcid = record['pmcid']
      pmcid.present? && !pmc_ids_seen.include?(pmcid)
    end

    # Track new PMCID entries and update PMC list
    new_pmc_records.each { |r| pmc_ids_seen << r['pmcid'] }
    pmc_records.concat(new_pmc_records)
    pmc_records.reject! { |r| r['pmcid'].blank? }
    pmc_records.uniq!
    # Update pubmed list
    remaining_pubmed_records.concat(new_pubmed_records)
    remaining_pubmed_records.uniq!

    # Overwrite files with adjusted lists
    File.open(pubmed_path, 'w') { |f| remaining_pubmed_records.each { |r| f.puts(r.to_json) } }
    File.open(pmc_path, 'w') { |f| pmc_records.each { |r| f.puts(r.to_json) } }

    Rails.logger.info("[adjust_id_lists_in_memory] Adjusted ID lists - PubMed: #{original_pubmed_record_size} to #{remaining_pubmed_records.size} records, PMC: #{original_pmc_record_size} to #{pmc_records.size} records")
    puts "[adjust_id_lists_in_memory] Adjusted ID lists - PubMed: #{original_pubmed_record_size} to #{remaining_pubmed_records.size} records, PMC: #{original_pmc_record_size} to #{pmc_records.size} records"
  end
end
