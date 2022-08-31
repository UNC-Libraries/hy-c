# frozen_string_literal: true
module Hyc
  module DownloadAnalyticsBehavior
    extend ActiveSupport::Concern

    included do
      after_action :track_download, only: :show

      def track_download
        if Hyrax.config.google_analytics_id.present? && !request.url.match('thumbnail')
          # Staccato works with Google Analytics v1 api:
          # https://developers.google.com/analytics/devguides/collection/protocol/v1/parameters
          # Staccato on Github: https://github.com/tpitale/staccato
          request_referrer = request.referrer
          medium = request_referrer.present? ? 'referral' : 'direct'
          tracker = Staccato.tracker(Hyrax.config.google_analytics_id)
          event = tracker.build_event(
            action: 'DownloadIR',
            campaign_medium: medium,
            category: @admin_set_name,
            data_source: 'server-side',
            hostname: request.host,
            label: params[:id],
            linkid: request.url,
            referrer: request_referrer,
            user_agent: request.headers['User-Agent'],
            user_ip: request.remote_ip
          )
          Rails.logger.debug("DownloadAnalyticsBehavior request_referrer: #{request_referrer}")
          event.track!
        end
      end
    end
  end
end
