# frozen_string_literal: true
module Hyc
  module DownloadAnalyticsBehavior
    extend ActiveSupport::Concern

    included do
      after_action :track_download, only: :show

      def track_download
        if bot_request?(request.user_agent)
          Rails.logger.debug("Bot request detected: #{request.user_agent}")
          return
        end
        if Hyrax::Analytics.config.auth_token.present? && !request.url.match('thumbnail')
          Rails.logger.debug("Recording download event for #{fileset_id}")
          medium = request.referrer.present? ? 'referral' : 'direct'

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
            apiv: '1',
            e_a: 'DownloadIR',
            e_c: @admin_set_name,
            e_n: fileset_id,
            e_v: medium,
            _id: client_id,
            cip: client_ip,
            send_image: '0',
            ua: user_agent,
            # Recovering work id with a solr query
            dimension1: record_id,
            dimension2: record_title
          }
          uri.query = URI.encode_www_form(uri_params)
          response = HTTParty.get(uri.to_s)
          Rails.logger.debug("Matomo download tracking URL: #{uri}")
          if response.code >= 300
            Rails.logger.error("DownloadAnalyticsBehavior received an error response #{response.code} for matomo query: #{uri}")
          end
          # Send download events to db
          create_download_stat
          Rails.logger.debug("DownloadAnalyticsBehavior request completed #{response.code}")
          response.code
        end
      end

      def create_download_stat
        record_id_value = record_id
        work_type_value = work_type
        admin_set_id_value = admin_set_id
        date = Date.today

        Rails.logger.debug('Creating or updating hyc-download-stat database entry with the following attributes:')
        Rails.logger.debug("fileset_id: #{fileset_id}, work_id: #{record_id_value}, admin_set_id: #{admin_set_id_value}, work_type: #{work_type_value}, date: #{date.beginning_of_month}")

        stat = HycDownloadStat.find_or_initialize_by(
          fileset_id: fileset_id,
          work_id: record_id_value,
          admin_set_id: admin_set_id_value,
          work_type: work_type_value,
          date: date.beginning_of_month
        )
        stat.download_count += 1
        if stat.save
          Rails.logger.debug("Database entry for fileset_id: #{fileset_id} successfully saved with download count: #{stat.download_count}.")
        else
          Rails.logger.error("Failed to update database entry for fileset_id: #{fileset_id}." \
                             "Errors: #{stat.errors.full_messages}")
        end
      end

      def bot_request?(user_agent)
        browser = Browser.new(user_agent)
        browser.bot?
      end

      def fetch_record
        @record ||= ActiveFedora::SolrService.get("file_set_ids_ssim:#{fileset_id}", rows: 1)['response']['docs']
      end

      def fetch_admin_set
        @admin_set ||= ActiveFedora::SolrService.get("title_tesim:#{@admin_set_name}", rows: 1)['response']['docs']
      end

      def admin_set_id
        @admin_set_id ||= fetch_admin_set.dig(0, 'id') || 'Unknown'
      end

      def record_id
        @record_id ||= fetch_record.dig(0, 'id') || 'Unknown'
      end

      def work_type
        @work_type ||= fetch_record.dig(0, 'has_model_ssim', 0) || 'Unknown'
      end

      def fileset_id
        @fileset_id ||= params[:id] || 'Unknown'
      end

      def record_title
        @record_title ||= if !fetch_record.blank? && fetch_record[0]['title_tesim']
                            fetch_record[0]['title_tesim'].first
                          else
                            'Unknown'
                          end
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

      def client_id
        cookie = cookies.find { |key, _| key.start_with?('_pk_id') }&.last
        if cookie.present?
          parts = cookie.to_s.split('.')
          return parts[0] if parts.length >= 2
        end
        # fall back to a random id
        return SecureRandom.uuid
      end

    end
  end
end
