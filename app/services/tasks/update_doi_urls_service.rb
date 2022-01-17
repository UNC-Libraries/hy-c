module Tasks
  require 'tasks/migrate/services/progress_tracker'

  class UpdateDoiUrlsService
    include HycHelper

    attr_reader :state, :rows, :retries, :end_date, :log, :completed_log, :failed_log

    def initialize(params, log)
      @state = params[:state]
      @rows = params[:rows]
      @retries = params[:retries].to_i
      @end_date = params[:end_date]
      @log = log
      @completed_log = Migrate::Services::ProgressTracker.new("#{params[:log_dir]}/completed_doi_updates.log")
      @failed_log = Migrate::Services::ProgressTracker.new("#{params[:log_dir]}/failed_doi_updates.log")
    end

    def update_dois
      puts "[#{Time.now}] starting doi updates"

      # set datacite variables
      doi_update_url = if state == 'test'
                         'https://api.test.datacite.org/dois'
                       else
                         'https://api.datacite.org/dois'
                       end

      datacite_user = ENV['DATACITE_USER']
      datacite_password = ENV['DATACITE_PASSWORD']

      updated = completed_log.completed_set + failed_log.completed_set

      start_time = Time.now
      records = ActiveFedora::SolrService.get("visibility_ssi:open AND doi_tesim:* AND workflow_state_name_ssim:deposited \
AND has_model_ssim:(DataSet HonorsThesis MastersPaper ScholarlyWork) AND system_create_dtsi:[* TO #{Date.parse(end_date).strftime('%Y-%m-%dT%H:%M:%SZ')}]",
                                              rows: rows,
                                              sort: "system_create_dtsi ASC",
                                              fl: "id,doi_tesim")["response"]["docs"]

      log.info "[#{Time.now}] no works with dois to be updated" if records.count.zero?

      count = 0

      # loop through records and update doi urls
      records.each_with_index do |record, index|
        next if updated.include? record['id']

        # check existing url
        get_response = fetch_doi_record(record['doi_tesim'].first.gsub('https://doi.org/', ''), doi_update_url, 2)

        if JSON.parse(get_response.parsed_response)['data']['url'].match(/data_sets|honors_theses|masters_papers|scholarly_works/)
          log.info "[#{Time.now}] doi for #{record['id']} is up-to-date"
          completed_log.add_entry(record['id'])
          next
        end

        log.info "[#{Time.now}] Updating doi for #{record['id']} (#{index + 1} of #{records.count})"

        work = ActiveFedora::Base.find(record['id'])
        data = format_update_data(work)

        update_response = doi_update_request(record['doi_tesim'].first.gsub('https://doi.org/', ''), data, retries, doi_update_url, datacite_user, datacite_password)

        if update_response.response.code.to_i == 200 && JSON.parse(update_response.parsed_response)['data']['url'].match(/data_sets|honors_theses|masters_papers|scholarly_works/)
          # log success
          completed_log.add_entry(record['id'])
          print '.'
          count += 1
        else
          # log failure
          failed_log.add_entry(record['id'])
          log.info "[#{Time.now}] failed to update doi for #{record['id']}: #{update_response.body}"
          print 'F'
        end
      end
      puts "[#{Time.now}] finished updating dois"
      log.info "[#{Time.now}] Finished updating #{count} doi(s) in #{Time.now - start_time}s"

      # return number of updates
      count
    end

    private

    def doi_update_request(id, data, retries, doi_update_url, datacite_user, datacite_password)
      begin
        return HTTParty.put("#{doi_update_url}/#{id}",
                            headers: { 'Content-Type' => 'application/vnd.api+json' },
                            basic_auth: {
                              username: datacite_user,
                              password: datacite_password
                            },
                            body: data
                           )
      rescue Net::ReadTimeout, Net::OpenTimeout => e
        if retries.positive?
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
      rescue => e # other failure
        # log failure
        log.info "[#{Time.now}] failed to update doi for #{id}: #{e.message}"
        log.info e.backtrace
        raise e
      end
    end

    def fetch_doi_record(id, doi_get_url, retries)
      begin
        return HTTParty.get("#{doi_get_url}/#{id}",
                            headers: { 'Content-Type' => 'application/vnd.api+json' }
                           )
      rescue Net::ReadTimeout, Net::OpenTimeout => e
        if retries.positive?
          retries -= 1
          log.info "[#{Time.now}] Timed out while attempting to fetch DOI record using #{doi_get_url}/#{id}, retrying with #{retries} retries remaining."
          sleep(30)
          return fetch_doi_record(id, doi_get_url, retries)
        else
          # log failure
          log.info "[#{Time.now}] failed to get doi record for #{id}: #{e.message}"
          log.info e.backtrace
          raise e
        end
      end
    end

    def format_update_data(work)
      data = {
        data: {
          type: 'dois',
          attributes: {
            url: get_work_url(work.class, work.id)
          }
        }
      }

      data.to_json
    end
  end
end
