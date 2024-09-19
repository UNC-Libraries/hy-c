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

          matomo_site_id = ENV['MATOMO_SITE_ID']
          matomo_security_token = ENV['MATOMO_AUTH_TOKEN']
          tracking_uri = URI("#{ENV['MATOMO_BASE_URL']}/matomo.php")

          # Some parameters are optional, but included since tracking would not work otherwise
          # https://developer.matomo.org/api-reference/tracking-api
          uri_params = {
            token_auth: matomo_security_token,
            rec: '1',
            idsite: matomo_site_id,
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
            dimension1: work_data[:work_id],
            dimension2: work_data[:title]
          }
          tracking_uri.query = URI.encode_www_form(uri_params)
          response = HTTParty.get(tracking_uri.to_s)
          Rails.logger.debug("Matomo download tracking URL: #{tracking_uri}")
          if response.code >= 300
            Rails.logger.error("DownloadAnalyticsBehavior received an error response #{response.code} for matomo query: #{tracking_uri}")
          end
          # Send download events to db
          create_download_stat
          Rails.logger.debug("DownloadAnalyticsBehavior request completed #{response.code}")
          response.code
        end
      end

      def create_download_stat
        date = Date.today

        Rails.logger.debug('Creating or updating hyc-download-stat database entry with the following attributes:')
        Rails.logger.debug("fileset_id: #{fileset_id}, work_id: #{work_data[:work_id]}, admin_set_id: #{work_data[:admin_set_id]}, work_type: #{work_data[:work_type]}, date: #{date.beginning_of_month}")

        stat = HycDownloadStat.find_or_initialize_by(
          fileset_id: fileset_id,
          work_id: work_data[:work_id],
          admin_set_id: work_data[:admin_set_id],
          work_type: work_data[:work_type],
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

      def fileset_id
        @fileset_id ||= params[:id] || 'Unknown'
      end

      def work_data
        @work_data ||= WorkUtilsHelper.fetch_work_data_by_fileset_id(fileset_id)
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
