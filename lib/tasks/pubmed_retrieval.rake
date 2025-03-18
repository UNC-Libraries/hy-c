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

desc 'Retrieve Pubmed articles'
# 2018-07-01 to today
task pubmed_retrieval: :environment do |task, args|
  progress = retrieve_stored_progress
  fetch_pubmed_ids(progress)
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
