# frozen_string_literal: true
# Task 1
# Query for UNC terms
# Harvest IDs of records
BASE_URL = 'https://search.nal.usda.gov/primaws/rest/pub/pnxs'
PROGRESS_FILE = 'progress.json'
ID_STORAGE = 'nal_ids.csv'

desc 'Retrieve list of UNC records from the National Agricultural Library'
task :nal_list_ids, [:out_dir] => :environment do |t, args|
  out_dir = args[:out_dir]
  FileUtils.mkdir_p(out_dir)
  list_path = File.join(out_dir, ID_STORAGE)

  progress = File.exist?(PROGRESS_FILE) && !File.zero?(PROGRESS_FILE) ? JSON.parse(File.read(PROGRESS_FILE)) : {}
  record_info = load_existing_records(ID_STORAGE)

  unc_variations = [
    'UNC-CH', 'UNC-Chapel Hill', 'UNC Chapel Hill',
    'University of North Carolina at Chapel Hill',
    'University of North Carolina Chapel Hill',
    'University of North Carolina-Chapel Hill',
    'University of North Carolina, Chapel Hill',
    'University of North Carolina-CH'
  ]

  unc_variations.each do |unc|
    process_variation(unc, list_path, progress, record_info)
  end
end

def load_existing_records(file)
  return {} unless File.exist?(file) && !File.zero?(file)

  CSV.read(file, headers: false).each_with_object({}) do |element, records|
    doi_url, title, record_id = element
    records[doi_url] = { title: title, record_id: record_id }
  end
end

def process_variation(unc, list_path, progress, record_info)
  limit = 50
  unc_progress = progress[unc] || {}
  offset = unc_progress['last_offset'] || 0
  total_records = unc_progress['total_record_count'] || 0

  return if total_records > 0 && offset >= total_records

  failed_attempts = 0
  retry_limit = 5

  while failed_attempts < retry_limit
    puts "[#{Time.now}] Retrieving records for #{unc} at offset #{offset}"
    data, headers = fetch_nal_records(unc, offset, limit)

    if data['docs'].empty?
      failed_attempts += 1
      puts "[#{Time.now}] No records found. Retrying in 10 seconds (#{failed_attempts}/#{retry_limit})..."
      sleep(10)
      next
    end

    total_records = data.dig('info', 'total').to_i if offset.zero?
    process_records(data, record_info)
    write_to_csv(list_path, record_info)
    offset += limit
    write_to_progress(progress, unc, offset, total_records)
    sleep(10)
    break if offset >= total_records
  end
end

def fetch_nal_records(unc, offset, limit)
  url = "#{BASE_URL}?acTriggered=false&disableCache=false&getMore=0&inst=01NAL_INST&lang=en" \
        "&limit=#{limit}&mode=advanced&offset=#{offset}&q=any,contains,#{CGI.escape(unc)}" \
        "&scope=pubag&tab=pubag&vid=01NAL_INST:MAIN"

  headers = construct_headers
  response = HTTParty.get(url, headers: headers)
  puts "URL: #{url}"
  puts "Response Code: #{response.code}, Response Body: #{response.body}"

  # WIP - Removing Cookie extraction for now
  # headers["Cookie"] = extract_cookies(response, headers)
  # puts "Cookies: #{headers['Cookie']}"
  [response.parsed_response || {}, headers]
end

def construct_headers
  {
    "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
    "Host" => "search.nal.usda.gov",
    "Connection" => "keep-alive",
    "Upgrade-Insecure-Requests" => "1",
    "Sec-Fetch-Dest" => "document",
    "Sec-Fetch-Mode" => "navigate",
    "Sec-Fetch-Site" => "none",
    "Sec-Fetch-User" => "?1",
    "Cache-Control" => "no-cache"
  }
end

def extract_cookies(response, headers)
  return headers["Cookie"] unless response.headers["Set-Cookie"]

  old_cookies = headers["Cookie"]&.split('; ')&.map(&:strip) || []
  new_cookies = response.headers["Set-Cookie"].split(', ').map { |c| c.split(';').first.strip } || []
  
  j_session = (new_cookies + old_cookies).find { |c| c.start_with?("JSESSIONID") } || ""
  urm_st = (new_cookies + old_cookies).find { |c| c.start_with?("urm_st") } || ""
  urm_se = (new_cookies + old_cookies).find { |c| c.start_with?("urm_se") } || ""
  secure = (new_cookies + old_cookies).find { |c| c.start_with?("__Secure-") } || ""

  "#{j_session.empty? ? '' : j_session + '; '}#{secure}; institute=01NAL_INST; #{urm_st}; #{urm_se}"
end

def process_records(data, record_info)
  data['docs'].each do |doc|
    next unless doc.dig('pnx', 'display')

    id_field = doc.dig('pnx', 'display', 'identifier')&.first
    title = doc.dig('pnx', 'display', 'title')&.first
    record_id = doc.dig('pnx', 'control', 'recordid')&.first
    doi_url = Nokogiri::HTML.fragment(id_field).at('a')['href'] rescue nil

    record_info[doi_url] ||= { title: title, record_id: record_id }
  end
end

def write_to_csv(file_path, record_info)
  CSV.open(file_path, 'wb') do |csv|
    record_info.each do |doi_url, data|
      csv << [doi_url, data[:title], data[:record_id]]
    end
  end
  puts "Finished write to record info CSV file: #{file_path}"
end

def write_to_progress(progress, unc, offset, total_records)
  progress[unc] = { last_offset: offset, total_record_count: total_records }
  File.write(PROGRESS_FILE, JSON.pretty_generate(progress))
  puts "Finished write to progress file: #{PROGRESS_FILE}"
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
