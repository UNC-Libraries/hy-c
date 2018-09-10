module Hyc
  class DownloadsController < Hyrax::DownloadsController
    include Hyc::DownloadAnalyticsBehavior
  end
end