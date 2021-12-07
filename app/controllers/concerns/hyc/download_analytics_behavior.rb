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
          tracker = Staccato.tracker(Hyrax.config.google_analytics_id)
          event = tracker.build_event(category: @admin_set_name,
                        action: 'DownloadIR',
                        hostname: request.host,
                        label: params[:id],
                        linkid: request.url,
                        referrer: request.referrer,
                        user_agent: request.headers['User-Agent'],
                        user_ip: request.remote_ip)
          event.track!
        end
      end
    end
  end
end
