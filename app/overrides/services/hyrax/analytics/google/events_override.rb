# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/hyrax-v3.5.0/app/services/hyrax/analytics/google/events.rb
Hyrax::Analytics::Google::Events.module_eval do
  # [hyc-override] use DownloadIR instead of file-set-in-work-download for download count
  filter(:file_set_in_work_download) { |_event_action| matches(:eventAction, 'DownloadIR') }
end
