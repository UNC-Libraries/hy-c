module Tasks
  require 'tasks/migrate/services/progress_tracker'

  class UpdateDoiUrlsService

    attr_reader :state, :rows, :retries, :end_date, :log, :completed_log

    def initialize(params, log)
      @state = params[:state]
      @rows = params[:rows]
      @retries = params[:retries]
      @end_date = params[:end_date]
      @log = log
      @completed_log = Migrate::Services::ProgressTracker.new("#{params[:log_dir]}/completed_doi_updates.log")
    end

    def update_dois
      puts "[#{Time.now}] starting doi updates"

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

      updated = completed_log.completed_set

      start_time = Time.now
      records = ActiveFedora::SolrService.get("visibility_ssi:open AND doi_tesim:* AND workflow_state_name_ssim:deposited \
AND has_model_ssim:(DataSet HonorsThesis MastersPaper ScholarlyWork) AND system_create_dtsi:[* TO #{Date.parse(end_date).strftime('%Y-%m-%dT%H:%M:%SZ')}]",
                                              :rows => rows,
                                              :sort => "system_create_dtsi ASC",
                                              :fl => "id,doi_tesim")["response"]["docs"]

      if records.count == 0
        log.info "[#{Time.now}] no works with dois to be updated"
      end

      count = 0

      # loop through records and update doi urls
      records.each_with_index do |record, index|
        if updated.include? record['id']
          next
        end
        log.info "[#{Time.now}] Updating doi for #{record['id']} (#{index+1} of #{records.count})"

        work = ActiveFedora::Base.find(record['id'])
        data = Hyc::DoiCreate.new.format_data(work)

        doi_update_request(record['doi_tesim'].first.gsub('https://doi.org/', ''), data, retries, doi_update_url, datacite_user, datacite_password)

        # log success
        completed_log.add_entry(record['id'])
        print '.'
        count += 1
      end
      puts "[#{Time.now}] finished updating dois"
      log.info "[#{Time.now}] Finished updating #{count} doi(s) in #{Time.now - start_time}s"

      # return number of updates
      count
    end


    private

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
            # log retry
            log.info "[#{Time.now}] retrying #{id}: #{e.message}"
            print 'R'
            retries -= 1
            log.info "[#{Time.now}] Timed out while attempting to create DOI using #{doi_update_url}/#{id}, retrying with #{retries} retries remaining."
            sleep(30)
            return doi_update_request(id, data, retries, doi_update_url, datacite_user, datacite_password)
          else
            # log failure
            log.info "[#{Time.now}] failed to update doi for #{id}: #{e.message}"
            log.info e.backtrace
            raise e
          end
        end
      end
  end
end