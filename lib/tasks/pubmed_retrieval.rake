desc 'Retrieve Pubmed articles'
task :pubmed_retrieval, [:year] => :environment do |task, args|
  year = args[:year]
  out_dir = Rails.root.join('public', 'pubmed', year)
  make_dir(out_dir)
  for month in 1..12
    # Determine max day for month
    retrieve_articles_for_month(year, month, out_dir)
    # WIP: Stop after 1 month for testing
    break
   end
    # Write to file
end

def make_dir(out_dir)
  unless File.directory?(out_dir)
    FileUtils.mkdir_p(out_dir)
    puts "📁 Created directory: #{out_dir}"
  else
    puts "📁 Directory already exists: #{out_dir}"
  end
end

def retrieve_articles_for_month(year, month, out_dir)
    max_day = Time.days_in_month(month)
    start_date = Date.new(year.to_i, month, 1).strftime('%Y-%m-%d')
    end_date = Date.new(year.to_i, month, max_day).strftime('%Y-%m-%d')
    request_url = "https://www.ncbi.nlm.nih.gov/pmc/utils/oa/oa.fcgi?from=#{start_date}&until=#{end_date}"
    response = HTTParty.get(request_url)
    pubmed_record_ids = Set.new
    puts "🔍 Retrieved articles for #{year}-#{month}"
    if response.ok?
        response_hash = process_response(response)
        response_hash['records'].each do |record|
            pubmed_record_ids.add(record.dig('id'))
        end
        # puts "🔍 Records: #{response_hash['records']}"
        # puts "🔍 Total Count: #{response_hash['total_count']}"
        # puts "🔍 Record End Number: #{response_hash['record_end_number']}"
        # puts "🔍 Resumption URL: #{response_hash['resumption_url']}"
        while response_hash['record_end_number'].to_i < response_hash['total_count'].to_i
            response = HTTParty.get(response_hash['resumption_url'])
            if response.ok?
                response_hash = process_response(response)
                response_hash['records'].each do |record|
                    pubmed_record_ids.add(record.dig('id'))
                end
            else
                puts "❌ Error retrieving articles for #{year}-#{month}"
                break
            end
        end
        puts "🔍 Pubmed Record IDs: #{pubmed_record_ids}"
    else
      puts "❌ Error retrieving articles for #{year}-#{month}"
    end
end

def process_response(response)
    parsed_response = response.parsed_response
    records = parsed_response.dig('OA', 'records', 'record')
    total_count = parsed_response.dig('OA', 'records', 'total_count')
    record_end_number = parsed_response.dig('OA', 'records', 'record_end_number')
    resumption_url = parsed_response.dig('OA', 'records', 'resumption', 'link', 'href')
    {
        'records' => records,
        'total_count' => total_count,
        'record_end_number' => record_end_number,
        'resumption_url' => resumption_url
    }
end
