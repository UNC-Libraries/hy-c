# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/v3.4.2/app/controllers/hyrax/downloads_controller.rb
Hyrax::DownloadsController.class_eval do
  # [hyc-override] adding downloads controller and merging hyc:downloadscontroller
  include Hyc::DownloadAnalyticsBehavior

  # [hyc-override] Loading the admin set for record
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
  def authorize_download!
    authorize! :download, params[asset_param_key]
  rescue CanCan::AccessDenied
    # [hyc-override] Send permission failures to 
    render_401
  end
end
