# frozen_string_literal: true
# [hyc-override] adding downloads controller and merging hyc:downloadscontroller
# [hyc-override] Catch not found errors and return 404
Hyrax::DownloadsController.class_eval do
  include Hyc::DownloadAnalyticsBehavior

  before_action :set_record_admin_set

  def set_record_admin_set
    record = ActiveFedora::SolrService.get("file_set_ids_ssim:#{params[:id]}", rows: 1)['response']['docs']

    @admin_set_name = if !record.blank?
                        record[0]['admin_set_tesim'].first
                      else
                        'Unknown'
                      end
  end

  private

  # Customize the :read ability in your Ability class, or override this method.
  # Hydra::Ability#download_permissions can't be used in this case because it assumes
  # that files are in a LDP basic container, and thus, included in the asset's uri.
  # [hyc-override] Catch not found errors and return 404
  def authorize_download!
    authorize! :download, params[asset_param_key]
  rescue CanCan::AccessDenied, Blacklight::Exceptions::RecordNotFound
    render_404
  end
end
