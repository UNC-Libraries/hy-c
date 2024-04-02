# frozen_string_literal: true
Hyrax::Analytics::Matomo.module_eval do
    # [hyc-override] https://github.com/samvera/hyrax/blob/hyrax-v3.5.0/app/services/hyrax/analytics/matomo.rb

  @@filter_pattern = nil
  class_methods do

    def daily_events_for_id(id, action, date = default_date_range)
      # Filter pattern to match views of the work; excluding stats
      @@filter_pattern = action == 'PageView' ? "&filter_pattern=^(?=\.\*\\bconcern\\b)(?=\.\*\\b#{id}\\b)" : ''
      additional_params = {
        flat: 1,
        # WIP: Conditional additional params for different events
        label: action == 'DownloadIR' ? "#{id} - #{action}" : nil,
      }
      method = action == 'DownloadIR' ? 'Events.getName' : 'Actions.getPageUrls'
      stat_field = action == 'DownloadIR' ? 'nb_events' : 'nb_visits'
      response = api_params(method, 'day', date, additional_params)
      results_array(response, stat_field)
    end

    def get(params)
      encoded_params = URI.encode_www_form(params)
      # Add filter_pattern separately without encoding
      requestURL = @@filter_pattern ? "#{config.base_url}/index.php?#{encoded_params}#{@@filter_pattern}" : "#{config.base_url}/index.php?#{encoded_params}"
      Rails.logger.debug("MATOMO GET requestURL=#{requestURL}")
      response = Faraday.get(requestURL)
      Rails.logger.debug("GET OVERRIDE: response=#{response.inspect}, response.status=#{response.status}")
      Rails.logger.debug("RESPONSE BODY: #{response.body.inspect}")
      return [] if response.status != 200
      JSON.parse(response.body)
    end

  end
end
