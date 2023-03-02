# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/hyrax-v3.5.0/app/services/hyrax/analytics/google/events_daily.rb
Hyrax::Analytics::Google::EventsDaily.module_eval do
  # [hyc-override] Add downloadIR event filter
  filter(:download_ir) { |_event_action| matches(:eventAction, 'DownloadIR') }
end
