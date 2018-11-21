module Hyc
  class DownloadsController < Hyrax::DownloadsController
    skip_before_action :check_read_only
    include Hyc::DownloadAnalyticsBehavior
  end
end