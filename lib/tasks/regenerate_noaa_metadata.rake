desc 'Regenerate NOAA OAI-PMH metadata files in existing directory structure'
task regenerate_noaa_oai_metadata: :environment do
  require 'net/http'
  require 'uri'
  
  records_dir = ENV['RECORDS_DIR'] || 'noaa/records'
  
  record_dirs = Dir.glob(File.join(records_dir, '*')).select { |f| File.directory?(f) }
  total = record_dirs.count
  
  puts "Regenerating OAI-PMH metadata for #{total} NOAA records..."
  
  record_dirs.each_with_index do |dir, idx|
    noaa_id = File.basename(dir)
    oai_file = File.join(dir, 'oai_pmh_metadata.xml')
    oai_identifier = "oai:noaa.stacks:noaa:#{noaa_id}"
    
    puts "[#{idx + 1}/#{total}] Fetching #{oai_identifier}..."
    
    url = "https://repository.library.noaa.gov/fedora/oai?verb=GetRecord&metadataPrefix=oai_dc&identifier=#{URI.encode_www_form_component(oai_identifier)}"
    
    begin
      response = Net::HTTP.get(URI(url))
      File.write(oai_file, response)
      puts "  ✓ Updated #{oai_file}"
      sleep 0.5
    rescue => e
      puts "  ❌ Error: #{e.message}"
    end
  end
  
  puts "\n✓ Done!"
end