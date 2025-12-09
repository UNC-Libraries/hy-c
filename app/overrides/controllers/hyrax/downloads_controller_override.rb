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

  def file_set_parent(file_set_id)
    file_set = if defined?(Wings) && Hyrax.metadata_adapter.is_a?(Wings::Valkyrie::MetadataAdapter)
                 Hyrax.query_service.find_by_alternate_identifier(alternate_identifier: file_set_id, use_valkyrie: Hyrax.config.use_valkyrie?)
               else
                 Hyrax.query_service.find_by(id: file_set_id)
               end
    @parent ||=
      case file_set
      when Hyrax::Resource
        Hyrax.query_service.find_parents(resource: file_set).first
      else
        # [hyc-override] If the object doesn't support parent, then throw an expected error
        if file_set.respond_to?(:parent)
          file_set.parent
        else
          raise Hyrax::WorkflowAuthorizationException
        end
      end
  end

  # Customize the :read ability in your Ability class, or override this method.
  # Hydra::Ability#download_permissions can't be used in this case because it assumes
  # that files are in a LDP basic container, and thus, included in the asset's uri.
  def authorize_download!
    authorize! :download, params[asset_param_key]
    parent = file_set_parent(params[asset_param_key])
    # Check if user has reviewer permissions
    user_is_reviewer = current_ability.can?(:review, parent)
    # Deny access if the work containing this file is restricted by a workflow and the user is not a reviewer
    if workflow_restriction?(parent, ability: current_ability) && !user_is_reviewer
      raise Hyrax::WorkflowAuthorizationException
    end
  rescue CanCan::AccessDenied, Hyrax::WorkflowAuthorizationException
    # [hyc-override] Send permission failures to
    render_401
  end
end
