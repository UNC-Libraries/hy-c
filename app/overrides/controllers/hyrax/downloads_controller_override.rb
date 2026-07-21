# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/hyrax-v5.2.0/app/controllers/hyrax/downloads_controller.rb
Hyrax::DownloadsController.class_eval do
  # [hyc-override] adding downloads controller and merging hyc:downloadscontroller
  include Hyc::DownloadAnalyticsBehavior
  alias hyc_stream_show_active_fedora show_active_fedora

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

  # [hyc-override] Overriding fedora file downloads to use send_file directly from fedora when possible
  def show_active_fedora
    local_original_path = fedora_binary_path_for(file)
    return send_fedora_binary_content(local_original_path) if local_original_path.present?

    Rails.logger.warn("DownloadsController: falling back to Fedora streaming for FileSet #{params[:id]}")
    hyc_stream_show_active_fedora
  end

  def send_fedora_binary_content(local_original_path)
    response.headers['Accept-Ranges'] = 'bytes'
    return unless stale?(last_modified: file_last_modified, template: false)

    Rails.logger.debug("DownloadsController: using local Fedora binary handoff for FileSet #{params[:id]} from #{local_original_path}")
    send_file local_original_path,
              content_options.merge(filename: file_name, type: file.mime_type)
  end

  def fedora_binary_path_for(repository_file)
    return unless original_file_request?
    return unless repository_file.is_a?(ActiveFedora::File)
    return if fedora_binary_store_path.blank?

    checksum = normalized_sha1_checksum_for(repository_file)
    return if checksum.blank?

    path = File.join(fedora_binary_store_path, *checksum.scan(/.{2}/).first(3), checksum)
    Rails.logger.debug("DownloadsController: returning fedora binary from path #{path}")
    path if File.exist?(path)
  end

  def fedora_binary_store_path
    ENV['FEDORA_BINARY_STORAGE'].presence
  end

  def normalized_sha1_checksum_for(repository_file)
    checksum = repository_file.checksum&.value.presence || repository_file.digest&.first.to_s.presence
    return if checksum.blank?

    normalized_checksum = checksum.sub(/\Aurn:sha1:/, '').sub(/\Asha1:/, '')
    normalized_checksum if normalized_checksum.match?(/\A\h{40}\z/)
  end

  def original_file_request?
    params[:file].blank? || params[:file].to_sym == self.class.default_content_path
  end

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
