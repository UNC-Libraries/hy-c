# frozen_string_literal: true
# Task 1
# Query for UNC terms
# Harvest IDs of records
BASE_URL = 'https://search.nal.usda.gov/primaws/rest/pub/pnxs'
desc 'Retrieve list of UNC records from the National Agricultural Library'
task :nal_list_ids, [:out_dir] => :environment do |t, args|
  limit = 1000
  record_ids = {}
  unc_variations = ['UNC-CH',
      'UNC-Chapel Hill',
      'UNC Chapel Hill',
      'University of North Carolina at Chapel Hill',
      'University of North Carolina Chapel Hill',
      'University of North Carolina-Chapel Hill',
      'University of North Carolina, Chapel Hill',
      'University of North Carolina-CH']
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
        fragmented_doc = Nokogiri::HTML.fragment(id_field)
        doi_link = fragmented_doc.at('a')['href'] rescue nil
        record_ids[doi_link] ||= title
      end
      sleep(5)
      offset += limit
      break unless end_of_cursor_range < total_record_count
    end

    CSV.open(list_path, 'wb') do |csv|
      csv << ['DOI Link', 'Title']
      record_ids.each do |doi_link, title|
        csv << [doi_link, title]
      end
    end
  end
end
