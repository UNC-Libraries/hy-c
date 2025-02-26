# frozen_string_literal: true
# Task 1
# Query for UNC terms
# Harvest IDs of records
desc 'Retrieve list of UNC records from the National Agricultural Library'
task :nal_list_ids, [:out_dir] => :environment do |t, args|
  unc_variations = ['UNC-CH',
      'UNC-Chapel Hill',
      'UNC Chapel Hill',
      'University of North Carolina at Chapel Hill',
      'University of North Carolina Chapel Hill',
      'University of North Carolina-Chapel Hill',
      'University of North Carolina, Chapel Hill',
      'University of North Carolina-CH']
  pub_years = ['2018', '2019', '2020', '2021', '2022', '2023', '2024', '2025']
  out_dir = args[:out_dir]
  FileUtils.mkdir_p(out_dir)
  list_path = File.join(out_dir, 'nal_ids.csv')

  base_url = 'https://search.nal.usda.gov/primaws/rest/pub/pnxs'
  limit = 50
  offset = 0
  record_ids = Set[]

    # unc_variations.each do |unc|
  pub_years.each do |year|
    start = 0
    has_next = false
    loop do
      unc = unc_variations[0]
      url = "#{base_url}?limit=#{limit}&offset=#{offset}&q=any,contains,%22university+of+north+carolina+at+chapel+hill%22&scope=pubag&sort=rank&tab=pubag&vid=01NAL_INST:MAIN"
      puts "[#{Time.now}] Retrieving records for #{unc} in #{year} starting at #{start}"
      puts "URL: #{url}"
        # Referer is required to get any response
      response = HTTParty.get(url)
      data = response.parsed_response
      # puts " 1 -- #{data.inspect}"
      # puts " 2 -- #{data['docs'].inspect}"
    #   puts "Inspecting Response #{response.inspect}"
      # File.open("response_log_2.txt", "w") do |file|  
      #   file.puts data.inspect
      # end      
      # File.open("response_log_3.txt", "w") do |file|  
      #   file.puts data['docs'].inspect
      # end      
      total_records ||= data['info']['total'] rescue nil
      docs = data['docs']
      docs.each do |doc|
        next unless doc['pnx']
        # puts "PNX #{doc['pnx']}"
        puts "#{doc['pnx']['display']['identifier']}"
        # File.open("response_log_4.txt", "w") do |file|  
        #   file.puts "PNX #{doc['pnx']}"
        # end      
        # id_field = doc['pnx']['identifier'][0] 
        # title = doc['pnx']['title'][0]
        # fragmented_doc = Nokogiri::HTML.fragment(id_field)
        # doi_link = fragmented_doc.at('a')['href'] rescue nil
        # puts "Link: #{doi_link} || Title: #{title}"
      end
        # WIP - Break to assess page
      break
        # Scrape For Links using CSS
        # Add record id to record ids set for each link in the page
        # Check if the page has a next link
        # Break if it does not
        # Add 10 to the start, no way to change the link amount from the url I know of
        # Log the current offset
        # Sleep to avoid sending requests too quickly
    end
      # WIP - Break to assess page
    break
  end
    # end

    # Open a CSV to write record ids into
end
