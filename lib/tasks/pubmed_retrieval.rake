# frozen_string_literal: true
PUBMED_SEARCH_URL = 'https://www.ncbi.nlm.nih.gov/pmc/utils/oa/oa.fcgi'
PUBMED_FETCH_URL = 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi'
UNC_VARIATIONS = ['UNC-CH',
'UNC-Chapel Hill',
'UNC Chapel Hill',
'University of North Carolina at Chapel Hill',
'University of North Carolina Chapel Hill',
'University of North Carolina-Chapel Hill',
'University of North Carolina, Chapel Hill',
'University of North Carolina-CH']
# OA API Defaults to 1000
BATCH_SIZE = 1000

# Output file
OUTPUT_CSV = 'pubmed_metadata.csv'
RETRIEVAL_PROGRESS_PATH = Rails.root.join('public', 'pubmed', 'retrieval_progress.json')

def retrieve_stored_progress
  if File.exist?(RETRIEVAL_PROGRESS_PATH)
    JSON.parse(File.read(RETRIEVAL_PROGRESS_PATH))
  else
    {}
  end
end

def generate_query_string(unc_variations)
  query = unc_variations.map { |var| "\"#{var}\"[Affiliation]" }.join(' OR ')
  "(#{query})"
end

def update_progress_info(stored_progress, xml_doc)
  new_progress_hash = {
      'total_count' => xml_doc.at_xpath('//records')['total-count'].to_i,
      'returned_count' => xml_doc.at_xpath('//records')['returned-count'].to_i,
      'start_number' => xml_doc.at_xpath('//records')['record-start-number'].to_i,
      'end_number' => xml_doc.at_xpath('//records')['record-end-number'].to_i,
      'resumption_token' => xml_doc.at_xpath('//resumption/link')['token'],
      'resumption_link' => xml_doc.at_xpath('//resumption/link')['href'],
      'pages_processed' => stored_progress.blank? ? 1 : stored_progress['pages_processed'] + 1
  }
  File.write(RETRIEVAL_PROGRESS_PATH, new_progress_hash.to_json)
  puts "📊 Wrote updated pagination information to #{RETRIEVAL_PROGRESS_PATH}"
  new_progress_hash
end

# Function to fetch PMIDs from PubMed
def fetch_pubmed_ids(stored_progress = {})
    # Retrieve progress information
  resumption_url = nil
  if stored_progress.present?
      # WIP: Short cutting if condition to test base case
      # if stored_progress["total_count"] <= stored_progress["pages_processed"] * BATCH_SIZE
    if 1000 <= stored_progress['pages_processed'] * BATCH_SIZE
      puts '🏁 All PMIDs have been fetched'
      return
    end

    if stored_progress['resumption_token'].present?
      resumption_url = stored_progress['resumption_link']
    end
  end

    # Fetch PMIDs from PubMed
  params = {
  db: 'pubmed',
  }
  unc_query_string = generate_query_string(UNC_VARIATIONS)
  encoded_query = CGI.escape(unc_query_string)
                    .gsub('%28', '(')
                    .gsub('%29', ')')
                    .gsub('%5B', '[')
                    .gsub('%5D', ']')
  encoded_params = URI.encode_www_form(params)
  url = resumption_url.present? ? resumption_url : "#{PUBMED_SEARCH_URL}?#{encoded_params}&term=#{encoded_query}"
  response = HTTParty.get(url, format: :plain)
  if response.ok?
    xml_doc = Nokogiri::XML(response.body)

      # Extract Records
    records = xml_doc.xpath('//record').map do |record|
      {
      'id' => record['id'],
      'citation' => record['citation'],
      'license' => record['license'],
      'retracted' => record['retracted'],
      'full_text_format' => record.at_xpath('./link')['format'],
      'full_text_href' => record.at_xpath('./link')['href']
      }
    end

    csv_output_file_path = Rails.root.join('public', 'pubmed', 'pubmed_metadata_oa.csv')
    headers = ['id', 'citation', 'license', 'retracted', 'full_text_format', 'full_text_href', 'cdr_url', 'has_fileset']
      # Only write headers if file is new or empty
    write_headers = !File.exist?(csv_output_file_path) || File.zero?(csv_output_file_path)

    CSV.open(csv_output_file_path, 'a', write_headers: write_headers, headers: headers) do |csv|
      records.each do |record|
        cdr_record = get_cdr_duplicate_data(record['id'])
        cdr_url = cdr_record.present? ? cdr_record[0] : nil
        has_fileset = cdr_record.present? ? cdr_record[1] : nil
        csv << [record['id'], record['citation'], record['license'], record['retracted'], record['full_text_format'], record['full_text_href'], cdr_url, has_fileset]
      end
    end
      # File.write(records_file_path, records.to_json)
    new_progress_hash = update_progress_info(stored_progress, xml_doc)
      # Recursively fetch PMIDs
    fetch_pubmed_ids(new_progress_hash)
  else
    puts '❌ Error fetching PMIDs from PubMed'
    return
  end
end



desc 'Retrieve Pubmed articles'
# 2018-07-01 to today
task pubmed_retrieval: :environment do |task, args|
  progress = retrieve_stored_progress
  fetch_pubmed_ids(progress)
end

# WIP: Finish after filtering out non UNC affiliated records
task :cdr_compare, [:year] => :environment do |task, args|
  year = args[:year]
  out_dir = Rails.root.join('public', 'pubmed', year)
  progress_json = if File.exist?(File.join(out_dir, 'cdr_compare_progress.json'))
                    JSON.parse(File.read(File.join(out_dir, 'cdr_compare_progress.json')))
                      else
                        {}
                      end
  (1..12).each do |month|
      # Skip if the month has been fully retrieved
    if progress_json[Date::MONTHNAMES[month]].present?
      next if progress_json[Date::MONTHNAMES[month]]['record_end_number'].to_i >= progress_json[Date::MONTHNAMES[month]]['total_count'].to_i
     end
      # M : Pubmed IDs
    article_ids = compare_cdr_for_month(year, month, out_dir, progress_json)
       # Write to file
      #  month_file_path = out_dir.join("#{Date::MONTHNAMES[month]}.csv")
      # WIP: Stop after 1 month for testing
    break
  end
end

def make_dir(out_dir)
  unless File.directory?(out_dir)
    FileUtils.mkdir_p(out_dir)
    puts "📁 Created directory: #{out_dir}"
  else
    puts "📁 Directory already exists: #{out_dir}"
  end
end


def compare_cdr_for_month(year, month, out_dir, progress_json)
  puts "🔍 Comparing CDR records for #{Date::MONTHNAMES[month]} in #{year}"
  file_path = File.join(out_dir, "#{Date::MONTHNAMES[month]}.csv")
  previously_compared_ids = Set.new(progress_json[Date::MONTHNAMES[month]]['compared_ids'])
  pubmed_record_ids = if File.exist?(file_path)
                        CSV.read(file_path).map { |row| row[0] }.to_set
  else
    Set.new
  end

  if pubmed_record_ids.empty?
    puts "Warning: No records found for #{Date::MONTHNAMES[month]} in #{year}"
    return
  end

  non_cdr_record_ids = []
  pubmed_record_ids.each do |pubmed_id|
    if previously_compared_ids.include?(pubmed_id)
      puts "Skipping #{pubmed_id} as it has already been compared"
      next
    end
    cdr_record = get_cdr_duplicate_data(pubmed_id)
    if cdr_record.present?
      non_cdr_record_ids << pubmed_id
    end
  end

  return non_cdr_record_ids
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


def retrieve_article_ids_for_month(year, month, out_dir, progress_json)
  file_path = File.join(out_dir, "#{Date::MONTHNAMES[month]}.csv")
  pubmed_record_ids = if File.exist?(file_path)
                        CSV.read(file_path).map { |row| row[0] }.to_set
                      else
                        Set.new
                      end
  max_day = Time.days_in_month(month)
  start_date = Date.new(year.to_i, month, 1).strftime('%Y-%m-%d')
  end_date = Date.new(year.to_i, month, max_day).strftime('%Y-%m-%d')
  request_url = "https://www.ncbi.nlm.nih.gov/pmc/utils/oa/oa.fcgi?from=#{start_date}&until=#{end_date}"
  response = HTTParty.get(request_url)

  if !response.ok?
    puts "❌ Error retrieving articles for the #{year}-#{month} initial request. Initiating retries"
    response = retry_request(request_url, year, month)
    if response.nil?
      puts "Out of retries for the #{year}-#{month} initial request. Exiting..."
      return
    end
  end

  response_hash = process_response(response)
    # Skip already retrieved records (prior to updates)
  update_files_and_progress_json(response_hash, file_path, progress_json, month, out_dir, pubmed_record_ids)
  puts "🔍 Retrieved articles for #{year}-#{month}. Range: #{response_hash['record_start_number']} - #{response_hash['record_end_number']} out of #{response_hash['total_count']}"
    # Retrieve additional records if available
  while response_hash['record_end_number'].to_i < response_hash['total_count'].to_i
    response = HTTParty.get(response_hash['resumption_url'])
    if response.ok?
       # Skip already retrieved records (prior to updates)
      response_hash = process_response(response)
      update_files_and_progress_json(response_hash, file_path, progress_json, month, out_dir, pubmed_record_ids)
      puts "🔍 Retrieved additional articles for #{year}-#{month}. Range: #{response_hash['record_start_number']} - #{response_hash['record_end_number']} out of #{response_hash['total_count']}"
    else
      puts "❌ Error retrieving articles for #{year}-#{month}. Initiating retries."
      puts "Last successful range: #{response_hash['record_start_number']} - #{response_hash['record_end_number']} out of #{response_hash['total_count']}"
      response = retry_request(response_hash['resumption_url'], year, month)
      if response.nil?
        puts "Out of retries for the #{year}-#{month} initial request. Exiting..."
        break
      else
           # Skip already retrieved records (prior to updates)
        response_hash = process_response(response)
        update_files_and_progress_json(response_hash, file_path, progress_json, month, out_dir, pubmed_record_ids)
        puts "🔍 Retrieved additional articles for #{year}-#{month}. Range: #{response_hash['record_start_number']} - #{response_hash['record_end_number']} out of #{response_hash['total_count']}"
      end
    end
      # Respect the API rate limit
    sleep(5)
  end
  return pubmed_record_ids
end

def update_files_and_progress_json(response_hash, file_path, current_progress_json, month, out_dir, pubmed_record_ids)
  skip_condition = current_progress_json[Date::MONTHNAMES[month]].present? && current_progress_json[Date::MONTHNAMES[month]]['record_end_number'].to_i >= response_hash['record_end_number'].to_i
  return if skip_condition
  add_records_to_set(response_hash['records'], pubmed_record_ids)
  write_to_file(response_hash['records'], file_path)
  update_progress_json(response_hash['total_count'], response_hash['record_end_number'], current_progress_json, month, out_dir)
end

def update_files_and_progress_json_for_compare(file_path, current_progress_json, month, out_dir, pubmed_record_ids)
end

def update_progress_json(total_count, record_end_number, current_progress_json, month, out_dir)
  current_progress_json[Date::MONTHNAMES[month]] = {
      'total_count' => total_count,
      'record_end_number' => record_end_number
  }
  File.write(File.join(out_dir, 'retrieval_progress.json'), current_progress_json.to_json)
  puts "📊 Updated progress JSON for #{Date::MONTHNAMES[month]}"
end

def write_to_file(records, file_path)
  write_headers = !File.exist?(file_path) || File.zero?(file_path)
    # Append new record ids to the file if it exists
  CSV.open(file_path, 'a', write_headers: write_headers, headers: ['id']) do |csv|
    records.each do |record|
      csv << [record.dig('id')]
    end
  end
  puts "📝 Wrote #{records.length} records to #{file_path}"
end

def retry_request(request_url, year, month)
  max_retries = 5
  seconds_to_sleep = 10
  retry_count = 0
  while retry_count < max_retries
    sleep(seconds_to_sleep)
    response = HTTParty.get(request_url)
    if response.ok?
      puts "🔍 Retrieved articles for #{year}-#{month} after #{retry_count} retries."
      return response
    else
      puts "❌ Error retrieving articles for #{year}-#{month}. Retrying..."
      puts "Retry count: #{retry_count} out of #{max_retries}"
      retry_count += 1
    end
  end
  return nil
end

def add_records_to_set(records, record_set)
  records.each do |record|
    record_set.add(record.dig('id'))
  end
end

def process_response(response)
  parsed_response = response.parsed_response
  records = parsed_response.dig('OA', 'records', 'record')
  total_count = parsed_response.dig('OA', 'records', 'total_count')
  record_end_number = parsed_response.dig('OA', 'records', 'record_end_number')
  record_start_number = parsed_response.dig('OA', 'records', 'record_start_number')
  resumption_url = parsed_response.dig('OA', 'records', 'resumption', 'link', 'href')
  {
      'records' => records,
      'total_count' => total_count,
      'record_start_number' => record_start_number,
      'record_end_number' => record_end_number,
      'resumption_url' => resumption_url
  }
end
