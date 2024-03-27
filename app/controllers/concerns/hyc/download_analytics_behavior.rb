# frozen_string_literal: true
module Hyc
  module DownloadAnalyticsBehavior
    extend ActiveSupport::Concern

    included do
      after_action :track_download, only: :show

      def track_download
        # wip: modified if condition, revert later
        if !request.url.match('thumbnail')
          Rails.logger.debug("Recording download event for #{params[:id]}")
          medium = request.referrer.present? ? 'referral' : 'direct'

          user_id = current_user.id if current_user
          client_ip = request.remote_ip
          user_agent = request.user_agent

          # wip: idsite, token_auth, differnt base url
          # not entirely sure if the mapping of ga to matomo params is correct
          # missing host_name
          matomo_id_site = site_id || '5'
          matomo_security_token = auth_token || 'c7b71dddc7f088a630ab1c2e3bb1a322'
          uri = URI("#{base_url}/matomo.php")
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
            # WIP: Will likely need to change this for downloads recorded from other sources
            # Intention is to capture the id of the work being downloaded
            # Using solr query to recover record_id
            e_n: record_id,
            e_v: medium,
            uid: client_id,
            _id: user_id,
            cip: client_ip,
            send_image: '0',
            ua: user_agent
          }
          # extracted_id = extract_id_from_referrer(request.referrer)
          # uri_params[:e_n] = extracted_id if extracted_id
          uri.query = URI.encode_www_form(uri_params)
          response = HTTParty.get(uri.to_s)
          Rails.logger.debug("Matomo Query Url #{uri}")
          if response.code >= 300
            Rails.logger.error("DownloadAnalyticsBehavior received an error response #{response.code} for query parameters: #{uri_params}")
          end
          Rails.logger.debug("DownloadAnalyticsBehavior request completed #{response.code}")
          Rails.logger.debug("DownloadAnalyticsBehavior request params #{uri_params}")
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

      def record_id
        record = ActiveFedora::SolrService.get("file_set_ids_ssim:#{params[:id]}", rows: 1)['response']['docs']

        @record_id = if !record.blank?
                       record[0]['id'].first
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

      def extract_id_from_referrer(referrer)
        return nil if referrer.nil? || referrer.empty?

        path_segments = referrer.split('/')
        concern_index = path_segments.index('concern')
        # If 'concern' exists in the path and there's at least one segment after it
        if concern_index && path_segments.length > concern_index + 1
          # Return the segment immediately after 'concern' as the ID
          return path_segments[concern_index + 1]
        else
          return nil
        end
      end

    end
  end
end
