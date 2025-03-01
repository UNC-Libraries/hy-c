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
  limit = 100
  out_dir = args[:out_dir]
  FileUtils.mkdir_p(out_dir)
  list_path = File.join(out_dir, ID_STORAGE)

  # Load progress if it exists
  progress =
  if File.exist?(PROGRESS_FILE) && !File.zero?(PROGRESS_FILE)
    JSON.parse(File.read(PROGRESS_FILE))
  else
    # Last offset, total number of records associated, title
    {}
  end
  record_info = if File.exist?(ID_STORAGE) && !File.zero?(ID_STORAGE)
                  CSV.read(ID_STORAGE, headers: false).to_h
  else
              # doi_url => title, alma id
    {}
  end
  last_saved_record_info = if File.exist?(ID_STORAGE) && !File.zero?(ID_STORAGE)
                             CSV.read(ID_STORAGE, headers: false).to_h
  else
    {}
  end

  puts "JSON: #{progress.inspect}"

  unc_variations = [
    'UNC-CH', 'UNC-Chapel Hill', 'UNC Chapel Hill',
    'University of North Carolina at Chapel Hill',
    'University of North Carolina Chapel Hill',
    'University of North Carolina-Chapel Hill',
    'University of North Carolina, Chapel Hill',
    'University of North Carolina-CH'
  ]


  pages_out = []
  total_record_count = 0

  unc_variations.each do |unc|
    unc_variation_progress = progress[unc] || {}
    offset = unc_variation_progress['last_offset'] || 0
    total_record_count = unc_variation_progress['total_record_count'] || 0

    skip_condition = total_record_count > 0 && offset >= total_record_count # Skip already completed
    puts "Skipped UNC Variation: #{unc}. Offset #{offset}, Total Records: #{total_record_count}" if skip_condition
    puts "UNC Variation: #{unc}. Offset #{offset}, Total Records: #{total_record_count}" if !skip_condition
    next if skip_condition

    loop do
      url = "#{BASE_URL}?limit=#{limit}&offset=#{offset}&q=any,contains,#{CGI.escape(unc)}&scope=pubag&sort=rank&tab=pubag&vid=01NAL_INST:MAIN"
      puts "[#{Time.now}] Retrieving records for #{unc} starting at #{offset}"
      puts "URL: #{url}"

      response = HTTParty.get(url)

      data = response.parsed_response || {}
      data['docs'] ||= [] # Prevent errors

      # Retry up to 3 times
      retries = 0
      max_retries = 3
      wait_time = 120
      # max_wait = 600

      while data['docs'].empty? && retries < max_retries
        puts "[#{Time.now}] No records returned. Retrying in #{wait_time} seconds (#{retries + 1}/#{max_retries})..."
        sleep(wait_time)
        response = HTTParty.get(url)
        data = response.parsed_response || {}
        data['docs'] ||= []
        # wait_time = [wait_time * 2, max_wait].min # Cap wait time
        retries += 1
      end

      # End the script early if the retries do not work
      if data['docs'].empty?
        puts "[#{Time.now}] No records found. Ending early."
        break
      end

      total_record_count = data.dig('info', 'total').to_i if offset.zero?
      end_of_cursor_range = data.dig('info', 'last') || 0
      docs = data['docs']

      debug_str =  "======= Offset: #{offset} / Total: #{total_record_count} / End of Cursor: #{end_of_cursor_range} / Variation: #{unc} ======="
      puts "DEBUG: #{debug_str}"

      docs.each do |doc|
        next unless doc['pnx']['display']

        id_field = doc['pnx']['display']['identifier'][0]
        title = doc['pnx']['display']['title'][0]
        record_id = doc['pnx']['control']['recordid'][0]
        fragmented_doc = Nokogiri::HTML.fragment(id_field)
        doi_url = fragmented_doc.at('a')['href'] rescue nil
        record_info[doi_url] ||= { title: title, record_id: record_id }
      end



      # progress[:in_progress][unc] ||= {
      #   total_record_count: total_record_count,
      #   last_offset: offset,
      #   is_complete: offset >= total_record_count
      # }

      # # Save progress
      # File.write(PROGRESS_FILE, JSON.pretty_generate({
      #   progress: progress[:in_progress]
      #   # last_variation: unc,
      #   # completed_variations: progress[:completed_variations],
      #   # total_record_count: total_record_count
      # }))

      sleep(90)  # Respect API limits
      offset += limit

      progress[unc] = { last_offset: offset, total_record_count: total_record_count }
      File.write(PROGRESS_FILE, JSON.pretty_generate(progress))

      break if offset >= total_record_count
    end

    unless last_saved_record_info == record_info
     # Write records to CSV
      CSV.open(list_path, 'wb') do |csv|
        record_info.each do |doi_url, data|
          csv << [doi_url, data[:title], data[:record_id]]
        end
      end
      last_saved_record_info = record_info
    end

    if offset < total_record_count
      puts 'Returning early...'
      return
    end

    # Mark this variation as completed
    # progress[:completed_variations] << unc
    # File.write(PROGRESS_FILE, JSON.pretty_generate(progress))
  end

  # # Write records to CSV
  # CSV.open(list_path, 'wb') do |csv|
  #   record_ids.each do |doi_url, data|
  #     csv << [doi_url, data[:title], data[:record_id]]
  #   end
  # end

  # Save progress file (final checkpoint)
  # File.write(PROGRESS_FILE, JSON.pretty_generate({
  #   last_offset: 0,
  #   last_variation: nil,
  #   completed_variations: unc_variations
  # }))

  # puts "Data collection complete!"
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
