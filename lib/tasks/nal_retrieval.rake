# frozen_string_literal: true
# Task 1
# Query for UNC terms
# Harvest IDs of records
BASE_URL = 'https://search.nal.usda.gov/primaws/rest/pub/pnxs'
require 'json'
require 'fileutils'

# File to store progress
PROGRESS_FILE = 'progress.json'
ID_STORAGE = 'nal_ids.csv'

desc 'Retrieve list of UNC records from the National Agricultural Library'
task :nal_list_ids, [:out_dir] => :environment do |t, args|
  out_dir = args[:out_dir]
  FileUtils.mkdir_p(out_dir)
  list_path = File.join(out_dir, ID_STORAGE)

  # Load progress file
  progress = if File.exist?(PROGRESS_FILE) && !File.zero?(PROGRESS_FILE)
               JSON.parse(File.read(PROGRESS_FILE))
             else
               {}
             end

  # Load record info from CSV if it exists
  # doi_url => title, alma id
  record_info = if File.exist?(ID_STORAGE) && !File.zero?(ID_STORAGE)
    CSV.read(ID_STORAGE, headers: false).each_with_object({}) do |element, accumulator_hash|
      doi_url, title, record_id = element
      accumulator_hash[doi_url] = { title: title, record_id: record_id }
    end
  else
    {}
  end
  puts "JSON Progress: #{progress.inspect}"

  unc_variations = [
    'UNC-CH', 
    'UNC-Chapel Hill', 'UNC Chapel Hill',
    'University of North Carolina at Chapel Hill',
    'University of North Carolina Chapel Hill',
    'University of North Carolina-Chapel Hill',
    'University of North Carolina, Chapel Hill',
    'University of North Carolina-CH'
  ]

  unc_variations.each do |unc|
    limit = 50
    unc_variation_progress = progress[unc] || {}
    offset = unc_variation_progress['last_offset'] || 0
    total_record_count = unc_variation_progress['total_record_count'] || 0

    skip_condition = total_record_count > 0 && offset >= total_record_count
    puts skip_condition ? "Skipped UNC Variation: #{unc} (Offset: #{offset}, Total: #{total_record_count})" :
                          "Processing UNC Variation: #{unc} (Offset: #{offset}, Total: #{total_record_count})"
    next if skip_condition

    failed_attempts = 0
    retry_limit = 3

    while failed_attempts < retry_limit
      remaining_record_count = total_record_count - offset

      url = "https://search.nal.usda.gov/primaws/rest/pub/pnxs?acTriggered=false&blendFacetsSeparately=false&citationTrailFilterByAvailability=true&disableCache=false&getMore=0&inst=01NAL_INST&isCDSearch=false&lang=en&limit=#{limit}&mode=advanced&newspapersActive=false&newspapersSearch=false&offset=#{offset}&otbRanking=false&pcAvailability=true&q=any,contains,UNC-Chapel+Hill&qExclude=&qInclude=&rapido=false&refEntryActive=false&rtaLinks=true&scope=pubag&searchInFulltextUserSelection=true&skipDelivery=Y&sort=rank&tab=pubag&vid=01NAL_INST:MAIN"

      puts "[#{Time.now}] Retrieving records for #{unc} starting at offset #{offset}"
      puts "URL: #{url}"

      response = HTTParty.get(url)
      data = response.parsed_response || {}
      data['docs'] ||= []

      # Retry logic
      retries = 0
      max_retries = 2
      wait_time = 30

      while data['docs'].empty? && retries < max_retries
        puts "[#{Time.now}] No records returned. Retrying in #{wait_time} seconds (#{retries + 1}/#{max_retries})..."
        sleep(wait_time)
        response = HTTParty.get(url)
        data = response.parsed_response || {}
        data['docs'] ||= []
        retries += 1
      end

      if data['docs'].empty?
        failed_attempts += 1
        puts "[#{Time.now}] No records found. Waiting 5 minutes before retrying variation: #{unc} (Attempt #{failed_attempts}/#{retry_limit})"
        sleep(300) # Wait 5 minutes before retrying
        next # Restart the loop for the same variation
      end

      total_record_count = data.dig('info', 'total').to_i if offset.zero?
      end_of_cursor_range = data.dig('info', 'last') || 0

      puts "Beginning Write, Response Successful"
      puts "======= Offset: #{offset} / Total: #{total_record_count} / End of Cursor: #{end_of_cursor_range} / Variation: #{unc} ======="

      data['docs'].each do |doc|
        next unless doc.dig('pnx', 'display')

        id_field = doc.dig('pnx', 'display', 'identifier')&.first
        title = doc.dig('pnx', 'display', 'title')&.first
        record_id = doc.dig('pnx', 'control', 'recordid')&.first 
        fragmented_doc = Nokogiri::HTML.fragment(id_field)
        doi_url = fragmented_doc.at('a')['href'] rescue nil

        record_info[doi_url] ||= { title: title, record_id: record_id }
      end

      puts "Writing To Record Info File"
      CSV.open(list_path, 'wb') do |csv|
        record_info.each do |doi_url, data|
          csv << [doi_url, data[:title], data[:record_id]]
        end
      end

      puts "Completed Write To Record Info File"
      offset += limit

      puts "Writing To Progress File"
      progress[unc] = { last_offset: offset, total_record_count: total_record_count }
      File.write(PROGRESS_FILE, JSON.pretty_generate(progress))
      puts "Completed Write To Record Info File"

      puts "Sleep to respect API rate limiting."
      sleep(180) # Respect API limits
      break if offset >= total_record_count
    end

    # Save CSV again in case the loop exited early
    CSV.open(list_path, 'wb') do |csv|
      record_info.each do |doi_url, data|
        csv << [doi_url, data[:title], data[:record_id]]
      end
    end

    if offset < total_record_count
      puts 'Skipping to next variation'
    end
  end
end



  # Task 2
  # Check for duplicate against CDR by DOI, PMID, PMCID IF there is no fileset
  # Produce a CSV file with metadata, including if it is a CDR duplicate, if
  # there's a fileset, list of all supplemental file
  # https://search.nal.usda.gov/primaws/rest/pub/pnxs/L/alma9916289359307426?vid=01NAL_INST:MAIN&lang=en&search_scope=pubag&adaptor=Local%20Search%20Engine&lang=en
desc 'Retrieve list of UNC records from NAL'
task :nal_export_md, [:out_dir] => :environment do |t, args|
  out_dir = args[:out_dir]
  list_path = File.join(out_dir, 'nal_ids.csv')
  md_file = File.join(out_dir, 'nal_metadata.csv')
  num_found = 0
  num_not_found = 0

  CSV.open(md_file, 'w') do |csv_out|
    csv_out << ['alma_id', 'doi', 'cdr_url', 'has_fileset']
    CSV.read(list_path).each do |row|
      doi_url = row[0]
      title = row[1]
      record_id = row[2]

      dup_data = nil
      if doi_url
        doi = doi_url.gsub(/https?:\/\/(dx\.)?doi\.org\//, '')
        dup_data = get_cdr_duplicate_data(doi)
      end

      # csv columns: doi, pmid, pmcid, cdr_url, has_fileset
      if dup_data.nil?
        csv_out << [record_id, doi_url, nil, nil]
        num_not_found += 1
      else
        csv_out << [record_id, doi_url, dup_data[0], dup_data[1]]
        num_found += 1
        num_with_fileset += 1 if dup_data[1]
      end

      sleep(1)
      # End List Path Read
    end
    # End MD Writing
  end
end

def get_cdr_duplicate_data(identifier)
  puts "[#{Time.now}] Searching for identifier_tesim:\"#{identifier}\""
  result = Hyrax::SolrService.get("identifier_tesim:\"#{identifier}\"",
                          rows: 1,
                          fl: 'id,title_tesim,has_model_ssim,file_set_ids_ssim')['response']['docs']
  if result.empty?
    return nil
  end
  record = result.first
  puts "[#{Time.now}] Found record for #{identifier}: #{record['id']}"
  model_type = record['has_model_ssim'].first.underscore + 's'
  has_fileset = record['file_set_ids_ssim'].present?
  base_url = 'https://cdr.lib.unc.edu/concern/'
  cdr_url = "#{base_url}#{model_type}/#{record['id']}"
  return [cdr_url, has_fileset]
end
