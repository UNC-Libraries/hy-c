# frozen_string_literal: true
module Hyc
  module DownloadAnalyticsBehavior
    extend ActiveSupport::Concern

    included do
      after_action :track_download, only: :show

      def track_download
        if Hyrax::Analytics.config.analytics_id.present? && !request.url.match('thumbnail')
          Rails.logger.debug("Recording download event for #{params[:id]}")
          medium = request.referrer.present? ? 'referral' : 'direct'
          body = {
              'client_id' => client_id,
              'events' => [
                {
                  'name' => 'DownloadIR',
                  'params' => {
                    'category' => @admin_set_name,
                    'label' => params[:id],
                    'host_name' => request.host,
                    'medium' => medium,
                    'page_referrer' => request.referrer,
                    'page_location' => request.url
                  }
                }
              ]
            }.to_json

          ga_id = Hyrax::Analytics.config.analytics_id
          url = "https://www.google-analytics.com/mp/collect?measurement_id=#{ga_id}&api_secret=#{api_secret}"
          response = HTTParty.post(url,
            {
              body: body
            })
          if response.code >= 300
            Rails.logger.error("DownloadAnalyticsBehavior received an error response #{response.code} for body: #{body}")
          end
          Rails.logger.debug("DownloadAnalyticsBehavior request completed #{response.code}")
          response.code
        end
      end

      def api_secret
        @api_secret ||= ENV['ANALYTICS_API_SECRET']
      end

      def client_id
        cookie = cookies[:_ga]
        if cookie.present?
          parts = cookie.to_s.split('.')
          return "#{parts[2]}.#{parts[3]}" if parts.length == 4
        end
        # fall back to a random id
        return SecureRandom.uuid if cookie.nil?
      end
    end
  end
end
