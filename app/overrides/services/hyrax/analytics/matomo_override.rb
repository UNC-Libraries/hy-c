Hyrax::Analytics::Matomo.module_eval do
    # [hyc-override] https://github.com/samvera/hyrax/blob/hyrax-v3.5.0/app/services/hyrax/analytics/matomo.rb
  class_methods do

    def daily_events_for_id(id, action, date = default_date_range)
      additional_params = {
        flat: 1,
        segment: additional_params_helper(id, action)
      #   label: "#{id} - #{action}"
      }
      response = api_params('Events.getName', 'week', date, additional_params)
      Rails.logger.debug("DAILY EVENTS FOR ID OVERRIDE RESPONSE: response=#{response}")
      results_array(response, 'nb_events')
    end

    def additional_params_helper(id, action)
      segment = ''
        # Filter by download event or pageview, and the id of the related work
        # https://developer.matomo.org/api-reference/reporting-api-segmentation
      if action == 'DownloadIR'
        segment = "eventAction==DownloadIR;eventName==#{id}"
      elsif action == 'work-view'
        segment = "actionType==pageviews;dimension1==#{id}"
      end
      segment
    end

  end
end
