module Hyc
  class DownloadsController < Hyrax::DownloadsController
    skip_before_action :check_read_only
    before_action :set_record_admin_set

    def set_record_admin_set
      record = ActiveFedora::SolrService.get("file_set_ids_ssim:#{params[:id]}", :rows => 1)["response"]["docs"]

      if !record.blank?
        @admin_set_name = record[0]['admin_set_tesim'].first
      else
        @admin_set_name = 'Unknown'
      end
    end

    include Hyc::DownloadAnalyticsBehavior
  end
end