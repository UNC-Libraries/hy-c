# [hyc-override] adding downloads controller and merging hyc:downloadscontroller
# [hyc-override] Catch not found errors and return 404
module Hyrax
  class DownloadsController < ApplicationController
    include Hydra::Controller::DownloadBehavior
    include Hyrax::LocalFileDownloadsControllerBehavior
    include Hyc::DownloadAnalyticsBehavior

    before_action :set_record_admin_set

    def self.default_content_path
      :original_file
    end

    # Render the 404 page if the file doesn't exist.
    # Otherwise renders the file.
    def show
      case file
        when ActiveFedora::File
          # For original files that are stored in fedora
          super
        when String
          # For derivatives stored on the local file system
          send_local_content
        else
          raise ActiveFedora::ObjectNotFoundError
      end
    end

    def set_record_admin_set
      record = ActiveFedora::SolrService.get("file_set_ids_ssim:#{params[:id]}", rows: 1)["response"]["docs"]

      @admin_set_name = if !record.blank?
                          record[0]['admin_set_tesim'].first
                        else
                          'Unknown'
                        end
    end

    private

    # Override the Hydra::Controller::DownloadBehavior#content_options so that
    # we have an attachement rather than 'inline'
    def content_options
      super.merge(disposition: 'attachment')
    end

    # Override this method if you want to change the options sent when downloading
    # a derivative file
    def derivative_download_options
      { type: mime_type_for(file), disposition: 'inline' }
    end

    # Customize the :read ability in your Ability class, or override this method.
    # Hydra::Ability#download_permissions can't be used in this case because it assumes
    # that files are in a LDP basic container, and thus, included in the asset's uri.
    # [hyc-override] Catch not found errors and return 404
    def authorize_download!
      authorize! :download, params[asset_param_key]
    rescue CanCan::AccessDenied, Blacklight::Exceptions::RecordNotFound
      render_404
    end

    # Overrides Hydra::Controller::DownloadBehavior#load_file, which is hard-coded to assume files are in BasicContainer.
    # Override this method to change which file is shown.
    # Loads the file specified by the HTTP parameter `:file`.
    # If this object does not have a file by that name, return the default file
    # as returned by {#default_file}
    # @return [ActiveFedora::File, File, NilClass] Returns the file from the repository or a path to a file on the local file system, if it exists.
    def load_file
      file_reference = params[:file]
      return default_file unless file_reference

      file_path = Hyrax::DerivativePath.derivative_path_for_reference(params[asset_param_key], file_reference)
      File.exist?(file_path) ? file_path : nil
    end

    def default_file
      default_file_reference = if asset.class.respond_to?(:default_file_path)
                                 asset.class.default_file_path
                               else
                                 DownloadsController.default_content_path
                               end
      association = dereference_file(default_file_reference)
      association&.reader
    end

    def mime_type_for(file)
      MIME::Types.type_for(File.extname(file)).first.content_type
    end

    def dereference_file(file_reference)
      return false if file_reference.nil?

      association = asset.association(file_reference.to_sym)
      association if association && association.is_a?(ActiveFedora::Associations::SingularAssociation)
    end
  end
end
