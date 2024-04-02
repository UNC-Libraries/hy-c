# frozen_string_literal: true
Hyrax::Analytics::Matomo.module_eval do
    # [hyc-override] https://github.com/samvera/hyrax/blob/hyrax-v3.5.0/app/services/hyrax/analytics/matomo.rb

  @@filter_pattern = nil
  class_methods do

    def daily_events_for_id(id, action, date = default_date_range)
      # Matching tracked views for a specific work excluding stats page views
      @@filter_pattern = action == 'PageView' ? "&filter_pattern=^(?=\.\*\\bconcern\\b)(?=\.\*\\b#{id}\\b)" : ''
      additional_params = {
        flat: 1,
        # Only including label for DownloadIR action
        label: action == 'DownloadIR' ? "#{id} - #{action}" : nil,
      }
      # Methods can be changed to return different stats from matomo
      # https://developer.matomo.org/api-reference/reporting-api
      method = action == 'DownloadIR' ? 'Events.getName' : 'Actions.getPageUrls'
      stat_field = action == 'DownloadIR' ? 'nb_events' : 'nb_visits'
      response = api_params(method, 'day', date, additional_params)
      results_array(response, stat_field)
    end

    def get(params)
      encoded_params = URI.encode_www_form(params)
      # Add filter_pattern separately without encoding
      requestURL = @@filter_pattern ? "#{config.base_url}/index.php?#{encoded_params}#{@@filter_pattern}" : "#{config.base_url}/index.php?#{encoded_params}"
      response = Faraday.get(requestURL)
      return [] if response.status != 200
      JSON.parse(response.body)
    end

  end
end
