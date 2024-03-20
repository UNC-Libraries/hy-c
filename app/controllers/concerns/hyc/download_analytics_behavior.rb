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

          # wip: idsite, token_auth, differnt base url
          matomo_id_site = '3'
          matomo_security_token = 'c7b71dddc7f088a630ab1c2e3bb1a322'

          base_url = "https://analytics-qa.lib.unc.edu/matomo.php"
          uri = URI(base_url)
          params = {
            idsite: matomo_id_site,
            rec: '1',
            url: request.url,
            e_a: 'DownloadIR',
            e_c: @admin_set_name,
            download: "test-id",
            uid: client_id,
            token_auth: matomo_security_token,
            urlref: request.referrer
          }
          uri.query = URI.encode_www_form(params)
          response = HTTParty.post(uri.to_s)
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
