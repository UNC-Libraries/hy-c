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

    base_url = 'https://search.nal.usda.gov/'
    record_ids = Set[]

    unc_variations.each do |unc|
        pub_years.each do |year|
            start = 0
            has_next = false
            loop do
                url = "#{base_url}discovery/search?query=any,contains,%22#{CGI.escape(unc)}%22&tab=pubag&search_scope=pubag&vid=01NAL_INST:MAIN&offset=0"
                puts "[#{Time.now}] Retrieving records for #{unc} in #{year} starting at #{start}"
                puts "URL: #{url}"
                # Referer is required to get any response
                response = HTTParty.get(url, headers: { 'Referer' => base_url })
                html = Nokogiri::HTML(response.body)
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
    end

    # Open a CSV to write record ids into
end
