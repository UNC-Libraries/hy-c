desc 'Retrieve Pubmed articles'
# 2018-07-01 to today
task :pubmed_retrieval, [:year] => :environment do |task, args|
  year = args[:year]
  out_dir = Rails.root.join('public', 'pubmed', year)
  make_dir(out_dir)
  progress_json = if File.exist?(File.join(out_dir, 'retrieval_progress.json'))
                    JSON.parse(File.read(File.join(out_dir, 'retrieval_progress.json')))
                    else
                    {}
                    end
  for month in 1..12
    # Skip if the month has been fully retrieved
    if progress_json[Date::MONTHNAMES[month]].present?
        next if progress_json[Date::MONTHNAMES[month]]['record_end_number'].to_i >= progress_json[Date::MONTHNAMES[month]]['total_count'].to_i
    end
    # M, Start, End, Total
    article_ids = retrieve_article_ids_for_month(year, month, out_dir, progress_json)
     # Write to file
    #  month_file_path = out_dir.join("#{Date::MONTHNAMES[month]}.csv")
    # WIP: Stop after 1 month for testing
    break
   end
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
    for month in 1..12
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

    if not response.ok?
        puts "❌ Error retrieving articles for the #{year}-#{month} initial request. Initiating retries"
        response = retry_request(request_url,year,month)
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
            response = retry_request(response_hash['resumption_url'],year,month)
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
        write_to_file(response_hash['records'],file_path)
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

def write_to_file(records,file_path)
    write_headers = !File.exist?(file_path) || File.zero?(file_path)
    # Append new record ids to the file if it exists
    CSV.open(file_path, 'a', write_headers: write_headers, headers: ['id']) do |csv|
        records.each do |record|
            csv << [record.dig('id')]
        end
    end
    puts "📝 Wrote #{records.length} records to #{file_path}"
end

def retry_request(request_url,year,month)
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
