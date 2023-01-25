# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/hyrax-v3.5.0/app/controllers/hyrax/downloads_controller.rb
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

  # This is unmodified from hyrax
  def file_set_parent(file_set_id)
    file_set = Hyrax.query_service.find_by_alternate_identifier(alternate_identifier: file_set_id, use_valkyrie: Hyrax.config.use_valkyrie?)
    @parent ||=
      case file_set
      when Hyrax::Resource
        Hyrax.query_service.find_parents(resource: file_set).first
      else
        file_set.parent
      end
  end

  # Customize the :read ability in your Ability class, or override this method.
  # Hydra::Ability#download_permissions can't be used in this case because it assumes
  # that files are in a LDP basic container, and thus, included in the asset's uri.
  def authorize_download!
    authorize! :download, params[asset_param_key]
    # Deny access if the work containing this file is restricted by a workflow
    return unless workflow_restriction?(file_set_parent(params[asset_param_key]), ability: current_ability)
    raise Hyrax::WorkflowAuthorizationException
  rescue CanCan::AccessDenied, Hyrax::WorkflowAuthorizationException
    # [hyc-override] Send permission failures to
    render_401
  end
end
