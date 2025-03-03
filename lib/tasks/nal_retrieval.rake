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
    limit = 100
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
      # remaining_record_count = total_record_count - offset

      # pre_req_url = "https://search.nal.usda.gov/primaws/rest/pub/pnxs?acTriggered=false&blendFacetsSeparately=false&citationTrailFilterByAvailability=true&disableCache=false&getMore=0&inst=01NAL_INST&isCDSearch=false&lang=en&limit=2&mode=advanced&newspapersActive=false&newspapersSearch=false&offset=1&otbRanking=false&pcAvailability=true&q=any,contains,#{CGI.escape(unc)}&qExclude=&qInclude=&rapido=false&refEntryActive=false&rtaLinks=true&scope=pubag&searchInFulltextUserSelection=true&skipDelivery=Y&sort=rank&tab=pubag&vid=01NAL_INST:MAIN"
      # pre_response = HTTParty.get(pre_req_url)
      # puts "Sent Prelim Response."
      # sleep(25)

      url = "https://search.nal.usda.gov/primaws/rest/pub/pnxs?acTriggered=false&blendFacetsSeparately=false&citationTrailFilterByAvailability=true&disableCache=false&getMore=0&inst=01NAL_INST&isCDSearch=false&lang=en&limit=#{limit}&mode=advanced&newspapersActive=false&newspapersSearch=false&offset=#{offset}&otbRanking=false&pcAvailability=true&q=any,contains,#{CGI.escape(unc)}&qExclude=&qInclude=&rapido=false&refEntryActive=false&rtaLinks=true&scope=pubag&searchInFulltextUserSelection=true&skipDelivery=Y&sort=rank&tab=pubag&vid=01NAL_INST:MAIN"

     secure = "_Secure-UqZBpD3n3naPU20-9Fvn5i-TQ-tMpchbYtbA9YCEpg3UXgo_=v1HDIygw__c7X; institute=01NAL_INST"
     j_session = "JSESSIONID=0941AD541B80E6EF70AFBFE312CCE5CC.apd04.na91.prod.almf.dc04.hosted.exlibrisgroup.com:1801"
     urm_st = "urm_st=1741032706314"
     urm_se = "urm_se=1741033606314"
     cookie_string = "#{secure}; institute=01NAL_INST; digitalDoc=#####----######; " \
        "_ga_3B6JN4Z2CV=GS1.1.1740688913.4.0.1740688921.52.0.0; " \
        "CFIWebMonSession=%7B%22GUID%22%3A%222ee56478-d44f-4f99-09cb-740433208021%22%2C%22EmailPhone%22%3A%22%22%2C%22HttpReferer%22%3A%22https%3A//www.google.com/%22%2C%22PageViews%22%3A5%2C%22CurrentRuleId%22%3Anull%2C%22CurrentPType%22%3A0%2C%22Activity%22%3A%22Browse%22%2C%22SessionStart%22%3A1740433208021%2C%22UnloadDate%22%3A1740688920771%2C%22WindowCount%22%3A0%2C%22LastPageStayTime%22%3A7331%2C%22AcceptOrDecline%22%3A%7B%7D%2C%22FirstBrowsePage%22%3A%22https%3A//www.nal.usda.gov/all-collections%22%2C%22FirstBrowseTime%22%3A1740688913440%2C%22FinallyLeaveTime%22%3A1740688913440%2C%22FinallyBrowsePage%22%3A%22https%3A//www.nal.usda.gov/all-collections%22%2C%22SiteReferrer%22%3A%22%22%2C%22LastPopUpPage%22%3Anull%2C%22TimeSpentonSite%22%3A0%2C%22GoogleAnalyticsValue%22%3Anull%2C%22Dimension%22%3Anull%2C%22CookiePath%22%3A%22/%3B%20domain%3Dnal.usda.gov%3B%20Secure%3B%22%2C%22AdditionalAttributes%22%3A%7B%7D%2C%22ClickTracker%22%3A%22url%3Dhttps%253A%252F%252Fwww.nal.usda.gov%252Fservices%252Fagdatacommons%252Fpolicies%26p%3D0%26elapsed%3D12666ms%26movement%3D1805px%7Curl%3Dhttps%253A%252F%252Fwww.nal.usda.gov%252F%26p%3D1%26elapsed%3D1689127ms%26movement%3D2664px%7Curl%3Dhttps%253A%252F%252Fwww.nal.usda.gov%252Fall-collections%26p%3D2%26elapsed%3D5793ms%26movement%3D447px%7Curl%3Dhttps%253A%252F%252Fwww.nal.usda.gov%252F%26p%3D3%26elapsed%3D75037691ms%26movement%3D1133px%7Curl%3Dhttps%253A%252F%252Fwww.nal.usda.gov%252Fall-collections%26p%3D4%26elapsed%3D7572ms%26movement%3D976px%22%2C%22PageIndex%22%3A5%7D; " \
        "_ga_ER98FFN75C=GS1.1.1740881386.9.1.1740881545.0.0.0; _ga_2YCFLHC3NC=GS1.1.1740881386.9.1.1740881545.0.0.0; " \
        "_ga_CSLL4ZEK4L=GS1.1.1740881386.9.1.1740881545.0.0.0; _ga=GA1.1.1942926067.1740432994; " \
        "_ga_VYRH7BQ1FL=GS1.1.1740881544.9.1.1740881546.0.0.0; #{j_session}; institute=01NAL_INST; #{urm_st}; #{urm_se}"

      
      headers = {
        "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
        "Cookie" => cookie_string,
        "Host" => "search.nal.usda.gov",
        "Connection" => "keep-alive",
        "Upgrade-Insecure-Requests" => "1",
        "Sec-Fetch-Dest" => "document",
        "Sec-Fetch-Mode" => "navigate",
        "Sec-Fetch-Site" => "none",
        "Sec-Fetch-User" => "?1",
        "Cache-Control" => "no-cache"
      }

      puts "[#{Time.now}] Retrieving records for #{unc} starting at offset #{offset}"
      puts "URL: #{url}"
    

      response = HTTParty.get(url, headers: headers)
      if response.headers["Set-Cookie"]
        # WIP: Extract the old cookies from the request headers, keep the unmodified ones
        # old_cookies = old_cookies = headers["Cookie"]&.split('; ') || []
        # cookies = response.headers["Set-Cookie"].split(', ').map { |c| c.split(';').first }
        # Extract old cookies (if they exist) and strip whitespace
        old_cookies = headers["Cookie"]&.split('; ')&.map(&:strip) || []
        # Extract new cookies from response headers and strip whitespace
        cookies = response.headers["Set-Cookie"]&.split(', ')&.map { |c| c.split(';').first.strip } || []
        j_session = (cookies + old_cookies).find { |c| c.start_with?("JSESSIONID") } || ""
        urm_st = (cookies + old_cookies).find { |c| c.start_with?("urm_st") } || ""
        urm_se = (cookies + old_cookies).find { |c| c.start_with?("urm_se") } || ""
        secure = (cookies + old_cookies).find { |c| c.start_with?("__Secure-") } || ""
        puts "Extracted Cookies: JSESSIONID=#{j_session}, URM_ST=#{urm_st}, URM_SE=#{urm_se}, Secure=#{secure}"
        # Construct the cleaned-up cookie string
        cookie_string = "#{secure}; institute=01NAL_INST; digitalDoc=#####----######; " \
          "_ga_3B6JN4Z2CV=GS1.1.1740688913.4.0.1740688921.52.0.0; " \
          "CFIWebMonSession=%7B%22GUID%22%3A%222ee56478-d44f-4f99-09cb-740433208021%22%2C%22EmailPhone%22%3A%22%22%2C%22HttpReferer%22%3A%22https%3A//www.google.com/%22%2C%22PageViews%22%3A5%2C%22CurrentRuleId%22%3Anull%2C%22CurrentPType%22%3A0%2C%22Activity%22%3A%22Browse%22%2C%22SessionStart%22%3A1740433208021%2C%22UnloadDate%22%3A1740688920771%2C%22WindowCount%22%3A0%2C%22LastPageStayTime%22%3A7331%2C%22AcceptOrDecline%22%3A%7B%7D%2C%22FirstBrowsePage%22%3A%22https%3A//www.nal.usda.gov/all-collections%22%2C%22FirstBrowseTime%22%3A1740688913440%2C%22FinallyLeaveTime%22%3A1740688913440%2C%22FinallyBrowsePage%22%3A%22https%3A//www.nal.usda.gov/all-collections%22%2C%22SiteReferrer%22%3A%22%22%2C%22LastPopUpPage%22%3Anull%2C%22TimeSpentonSite%22%3A0%2C%22GoogleAnalyticsValue%22%3Anull%2C%22Dimension%22%3Anull%2C%22CookiePath%22%3A%22/%3B%20domain%3Dnal.usda.gov%3B%20Secure%3B%22%2C%22AdditionalAttributes%22%3A%7B%7D%2C%22ClickTracker%22%3A%22url%3Dhttps%253A%252F%252Fwww.nal.usda.gov%252Fservices%252Fagdatacommons%252Fpolicies%26p%3D0%26elapsed%3D12666ms%26movement%3D1805px%7Curl%3Dhttps%253A%252F%252Fwww.nal.usda.gov%252F%26p%3D1%26elapsed%3D1689127ms%26movement%3D2664px%7Curl%3Dhttps%253A%252F%252Fwww.nal.usda.gov%252Fall-collections%26p%3D2%26elapsed%3D5793ms%26movement%3D447px%7Curl%3Dhttps%253A%252F%252Fwww.nal.usda.gov%252F%26p%3D3%26elapsed%3D75037691ms%26movement%3D1133px%7Curl%3Dhttps%253A%252F%252Fwww.nal.usda.gov%252Fall-collections%26p%3D4%26elapsed%3D7572ms%26movement%3D976px%22%2C%22PageIndex%22%3A5%7D; " \
          "_ga_ER98FFN75C=GS1.1.1740881386.9.1.1740881545.0.0.0; _ga_2YCFLHC3NC=GS1.1.1740881386.9.1.1740881545.0.0.0; " \
          "_ga_CSLL4ZEK4L=GS1.1.1740881386.9.1.1740881545.0.0.0; _ga=GA1.1.1942926067.1740432994; " \
          "_ga_VYRH7BQ1FL=GS1.1.1740881544.9.1.1740881546.0.0.0; #{j_session}; institute=01NAL_INST; #{urm_st}; #{urm_se}"

      # Update headers only if new_cookies are found
      headers["Cookie"] = cookie_string unless cookie_string.empty?
      else
        puts "No Set-Cookie headers found in the response."
      end

      data = response.parsed_response || {}
      is_valid_response = data.key?('docs') && data['docs'].is_a?(Array)

      if is_valid_response
        # Safe to use data['docs'] here
        data['docs'] ||= []
      end

      # Retry logic
      retries = 0
      max_retries = 5
      wait_time = 10

      while data['docs'].empty? && retries < max_retries
        puts "[#{Time.now}] No records returned. Retrying in #{wait_time} seconds (#{retries + 1}/#{max_retries})..."
        # sleep(wait_time)
        # pre_req_url = "https://search.nal.usda.gov/primaws/rest/pub/pnxs?acTriggered=false&blendFacetsSeparately=false&citationTrailFilterByAvailability=true&disableCache=false&getMore=0&inst=01NAL_INST&isCDSearch=false&lang=en&limit=2&mode=advanced&newspapersActive=false&newspapersSearch=false&offset=1&otbRanking=false&pcAvailability=true&q=any,contains,#{CGI.escape(unc)}&qExclude=&qInclude=&rapido=false&refEntryActive=false&rtaLinks=true&scope=pubag&searchInFulltextUserSelection=true&skipDelivery=Y&sort=rank&tab=pubag&vid=01NAL_INST:MAIN"
        # pre_response = HTTParty.get(pre_req_url)
        # puts "Sent Prelim Response."
        sleep(10)
        # puts "Sending Actual Response."
        response = HTTParty.get(url, headers: headers)
        if response.headers["Set-Cookie"]
          # WIP: Extract the old cookies from the request headers, keep the unmodified ones
          # old_cookies = old_cookies = headers["Cookie"]&.split('; ') || []
          # cookies = response.headers["Set-Cookie"].split(', ').map { |c| c.split(';').first }
          # Extract old cookies (if they exist) and strip whitespace
          old_cookies = headers["Cookie"]&.split('; ')&.map(&:strip) || []
          # Extract new cookies from response headers and strip whitespace
          cookies = response.headers["Set-Cookie"]&.split(', ')&.map { |c| c.split(';').first.strip } || []
          j_session = (cookies + old_cookies).find { |c| c.start_with?("JSESSIONID") } || ""
          urm_st = (cookies + old_cookies).find { |c| c.start_with?("urm_st") } || ""
          urm_se = (cookies + old_cookies).find { |c| c.start_with?("urm_se") } || ""
          secure = (cookies + old_cookies).find { |c| c.start_with?("__Secure-") } || ""
          puts "Extracted Cookies: JSESSIONID=#{j_session}, URM_ST=#{urm_st}, URM_SE=#{urm_se}, Secure=#{secure}"
          # Construct the cleaned-up cookie string
          cookie_string = "#{secure}; institute=01NAL_INST; digitalDoc=#####----######; " \
          "_ga_3B6JN4Z2CV=GS1.1.1740688913.4.0.1740688921.52.0.0; " \
          "CFIWebMonSession=%7B%22GUID%22%3A%222ee56478-d44f-4f99-09cb-740433208021%22%2C%22EmailPhone%22%3A%22%22%2C%22HttpReferer%22%3A%22https%3A//www.google.com/%22%2C%22PageViews%22%3A5%2C%22CurrentRuleId%22%3Anull%2C%22CurrentPType%22%3A0%2C%22Activity%22%3A%22Browse%22%2C%22SessionStart%22%3A1740433208021%2C%22UnloadDate%22%3A1740688920771%2C%22WindowCount%22%3A0%2C%22LastPageStayTime%22%3A7331%2C%22AcceptOrDecline%22%3A%7B%7D%2C%22FirstBrowsePage%22%3A%22https%3A//www.nal.usda.gov/all-collections%22%2C%22FirstBrowseTime%22%3A1740688913440%2C%22FinallyLeaveTime%22%3A1740688913440%2C%22FinallyBrowsePage%22%3A%22https%3A//www.nal.usda.gov/all-collections%22%2C%22SiteReferrer%22%3A%22%22%2C%22LastPopUpPage%22%3Anull%2C%22TimeSpentonSite%22%3A0%2C%22GoogleAnalyticsValue%22%3Anull%2C%22Dimension%22%3Anull%2C%22CookiePath%22%3A%22/%3B%20domain%3Dnal.usda.gov%3B%20Secure%3B%22%2C%22AdditionalAttributes%22%3A%7B%7D%2C%22ClickTracker%22%3A%22url%3Dhttps%253A%252F%252Fwww.nal.usda.gov%252Fservices%252Fagdatacommons%252Fpolicies%26p%3D0%26elapsed%3D12666ms%26movement%3D1805px%7Curl%3Dhttps%253A%252F%252Fwww.nal.usda.gov%252F%26p%3D1%26elapsed%3D1689127ms%26movement%3D2664px%7Curl%3Dhttps%253A%252F%252Fwww.nal.usda.gov%252Fall-collections%26p%3D2%26elapsed%3D5793ms%26movement%3D447px%7Curl%3Dhttps%253A%252F%252Fwww.nal.usda.gov%252F%26p%3D3%26elapsed%3D75037691ms%26movement%3D1133px%7Curl%3Dhttps%253A%252F%252Fwww.nal.usda.gov%252Fall-collections%26p%3D4%26elapsed%3D7572ms%26movement%3D976px%22%2C%22PageIndex%22%3A5%7D; " \
          "_ga_ER98FFN75C=GS1.1.1740881386.9.1.1740881545.0.0.0; _ga_2YCFLHC3NC=GS1.1.1740881386.9.1.1740881545.0.0.0; " \
          "_ga_CSLL4ZEK4L=GS1.1.1740881386.9.1.1740881545.0.0.0; _ga=GA1.1.1942926067.1740432994; " \
          "_ga_VYRH7BQ1FL=GS1.1.1740881544.9.1.1740881546.0.0.0; #{j_session}; institute=01NAL_INST; #{urm_se}; #{urm_st}"

          puts "Inspect cookie string: #{cookie_string}"
  
        # Update headers only if new_cookies are found
        headers["Cookie"] = cookie_string unless cookie_string.empty?
        else
          puts "No Set-Cookie headers found in the response."
        end
        # puts "Inspecting Response #{response.inspect}"
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
      break if offset >= total_record_count


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
      # 5 seconds
      # WIP change
      sleep(5) # Respect API limits
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
