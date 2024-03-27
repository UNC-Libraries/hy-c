# frozen_string_literal: true
Hyrax::Analytics::Matomo.module_eval do
    # [hyc-override] https://github.com/samvera/hyrax/blob/hyrax-v3.5.0/app/services/hyrax/analytics/matomo.rb
  class_methods do

    def daily_events_for_id(id, action, date = default_date_range)
      additional_params = {
        flat: 1,
        # WIP: Conditional additional params for different events
        label: action == 'DownloadIR' ? "#{id} - #{action}" : nil,
        # Filter pattern to match views of the work; excluding stats
        filter_pattern: action == 'PageView' ? "^(?=.*\bconcern\b)(?=.*\b#{id}\b) : nil"
      }
      method = action == 'DownloadIR' ? 'Events.getName' : 'Actions.getPageUrls'
      response = api_params(method, 'day', date, additional_params)
      results_array(response, 'nb_events')
    end

    # def additional_params_helper(id, action)
    #   segment = ''
    #     # Filter by download event or pageview, and the id of the related work
    #     # https://developer.matomo.org/api-reference/reporting-api-segmentation
    #   if action == 'DownloadIR'
    #     # Thinking the ID of the record is different from the ID of the event
    #     # Seems like the ID of the event being recorded corresponds to some identifier retrieved from the download url.
    #     # segment = "eventAction==DownloadIR;eventName==#{id}"
    #     segment = "eventAction==DownloadIR"
    #   elsif action == 'work-view'
    #     # segment = "actionType==pageviews;dimension1==#{id}"
    #     segment = "actionType==pageviews"
    #   end
    #   segment
    # end

    def get(params)
      encoded_params = URI.encode_www_form(params)
      response = Faraday.get("#{config.base_url}/index.php?#{encoded_params}")
      Rails.logger.debug("GET OVERRIDE: response=#{response.inspect}, response.status=#{response.status}")
      Rails.logger.debug("RESPONSE BODY: #{response.body.inspect}")
      return [] if response.status != 200
      JSON.parse(response.body)
    end

  end
end
