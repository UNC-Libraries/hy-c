desc "Updates URL for DOI records"
task :update_doi_urls, [:state, :rows, :retries] => :environment do |t, args|
  state = args[:state]
  rows = args[:rows]
  retries = args[:retries]

  # set datacite variables
  if state == 'test'
    doi_update_url = 'https://api.test.datacite.org/dois'
    datacite_user = ENV['DATACITE_TEST_USER']
    datacite_password = ENV['DATACITE_TEST_PASSWORD']
  else
    doi_update_url = 'https://api.datacite.org/dois'
    datacite_user = ENV['DATACITE_USER']
    datacite_password = ENV['DATACITE_PASSWORD']
  end

  start_time = Time.now
  records = ActiveFedora::SolrService.get("visibility_ssi:open AND doi_tesim:* AND workflow_state_name_ssim:deposited AND has_model_ssim:(DataSet HonorsThesis MastersPaper ScholarlyWork)",
                                          :rows => rows,
                                          :sort => "system_create_dtsi ASC",
                                          :fl => "id,doi_tesim")["response"]["docs"]

  # loop through records and update doi urls
  records.each_with_index do |record|
    puts "[#{Time.now}] Updating doi for #{record['id']} (#{index+1} of #{records.count})"
    # update doi record in datacite
    # not sure if i need to recreate the whole record or if i can just send the id and url

    work = ActiveFedora::Base.find(record['id'])
    data = Hyc::DoiCreate.new.format_data(work)

    doi_update_request(record['doi_tesim'], data, retries, doi_update_url, datacite_user, datacite_password)

  puts "[#{Time.now}] Finished updating #{records.count} dois in #{Time.now - start_time}s"
  end
end

def doi_update_request(id, data, retries, doi_update_url, datacite_user, datacite_password)
  begin
    return HTTParty.post("#{doi_update_url}/#{id}",
                         headers: {'Content-Type' => 'application/vnd.api+json'},
                         basic_auth: {
                             username: datacite_user,
                             password: datacite_password
                         },
                         body: data
    )
  rescue Net::ReadTimeout, Net::OpenTimeout => e
    if retries > 0
      retries -= 1
      puts "Timed out while attempting to create DOI using #{doi_update_url}/#{id}, retrying with #{retries} retries remaining."
      sleep(30)
      return doi_request(data, retries)
    else
      raise e
    end
  end
end
