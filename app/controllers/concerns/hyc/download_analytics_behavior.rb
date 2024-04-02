# frozen_string_literal: true
module Hyc
  module DownloadAnalyticsBehavior
    extend ActiveSupport::Concern

    included do
      after_action :track_download, only: :show

      def track_download
        if Hyrax::Analytics.config.auth_token.present? && !request.url.match('thumbnail')
          Rails.logger.debug("Recording download event for #{params[:id]}")
          medium = request.referrer.present? ? 'referral' : 'direct'

          user_id = current_user.id if current_user
          client_ip = request.remote_ip
          user_agent = request.user_agent

          matomo_id_site = site_id
          matomo_security_token = auth_token
          uri = URI("#{base_url}/matomo.php")

          # Some parameters are optional, but included since tracking would not work otherwise
          # https://developer.matomo.org/api-reference/tracking-api
          uri_params = {
            token_auth: matomo_security_token,
            rec: '1',
            idsite: matomo_id_site,
            action_name: 'Download',
            url: request.url,
            urlref: request.referrer,
            rand: rand(1_000_000).to_s,
            apiv: '1',
            e_a: 'DownloadIR',
            e_c: @admin_set_name,
            # Recovering work id with a solr query
            e_n: work_id || 'Unknown',
            e_v: medium,
            uid: client_id,
            _id: user_id,
            cip: client_ip,
            send_image: '0',
            ua: user_agent
          }
          uri.query = URI.encode_www_form(uri_params)
          response = HTTParty.get(uri.to_s)
          Rails.logger.debug("Matomo download tracking URL: #{uri}")
          if response.code >= 300
            Rails.logger.error("DownloadAnalyticsBehavior received an error response #{response.code} for matomo query: #{uri}")
          end
          Rails.logger.debug("DownloadAnalyticsBehavior request completed #{response.code}")
          response.code
        end
      end

      def api_secret
        @api_secret ||= ENV['ANALYTICS_API_SECRET']
      end

      def site_id
        @site_id ||= ENV['MATOMO_SITE_ID']
      end

      def auth_token
        @auth_token ||= ENV['MATOMO_AUTH_TOKEN']
      end

      def base_url
        @base_url ||= ENV['MATOMO_BASE_URL']
      end

      def work_id
        return nil if params[:id].nil?

        record = ActiveFedora::SolrService.get("file_set_ids_ssim:#{params[:id]}", rows: 1)['response']['docs']

        @work_id = if !record.blank?
                     record[0]['id']
                          else
                            'Unknown'
                          end
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
