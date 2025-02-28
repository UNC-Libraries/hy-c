# frozen_string_literal: true
# Task 1
# Query for UNC terms
# Harvest IDs of records
BASE_URL = 'https://search.nal.usda.gov/primaws/rest/pub/pnxs'
desc 'Retrieve list of UNC records from the National Agricultural Library'
task :nal_list_ids, [:out_dir] => :environment do |t, args|
  limit = 1000
  # WIP - Remove Later
  # limit = 1
  record_ids = {}
  unc_variations = ['UNC-CH',
  'UNC-Chapel Hill',
  'UNC Chapel Hill',
  'University of North Carolina at Chapel Hill',
  'University of North Carolina Chapel Hill',
  'University of North Carolina-Chapel Hill',
  'University of North Carolina, Chapel Hill',
  'University of North Carolina-CH']
  # WIP - Remove Later
  # unc_variations = [
  #     'UNC-Chapel Hill',
  #     'University of North Carolina, Chapel Hill',]
  out_dir = args[:out_dir]
  FileUtils.mkdir_p(out_dir)
  list_path = File.join(out_dir, 'nal_ids.csv')

  unc_variations.each do |unc|
    offset = 0
      # Start Pagination
    loop do
      url = "#{BASE_URL}?limit=#{limit}&offset=#{offset}&q=any,contains,#{CGI.escape(unc)}&scope=pubag&sort=rank&tab=pubag&vid=01NAL_INST:MAIN"
      puts "[#{Time.now}] Retrieving records for #{unc} starting at #{offset}"
      response = HTTParty.get(url)
      data = response.parsed_response
      total_record_count = data['info']['total']
      end_of_cursor_range = data['info']['last']
      docs = data['docs']
      docs.each do |doc|
        next unless doc['pnx']['display']
        id_field = doc['pnx']['display']['identifier'][0]
        title = doc['pnx']['display']['title'][0]
        record_id = doc['pnx']['control']['recordid'][0]
        fragmented_doc = Nokogiri::HTML.fragment(id_field)
        doi_url = fragmented_doc.at('a')['href'] rescue nil
        record_ids[doi_url] ||= {title: title, record_id: record_id}
      end
      sleep(5)
      offset += limit
      break unless end_of_cursor_range < total_record_count
      # WIP - Remove Later
      # break
    end
  end

  CSV.open(list_path, 'wb') do |csv|
    record_ids.each do |doi_url, data|
      csv << [doi_url, data[:title], data[:record_id]]
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
