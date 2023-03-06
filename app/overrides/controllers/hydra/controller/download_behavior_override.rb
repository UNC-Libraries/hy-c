# frozen_string_literal: true
# [hyc-override] Add file extension on download
#
Hydra::Controller::DownloadBehavior.class_eval do
  protected

  # [hyc-override] Remove from upstream behavior in order to use the default 404 from ApplicationController
  remove_method :render_404

  # [hyc-override] Add extension to files on download
  # Override this if you'd like a different filename
  # @return [String] the filename
  def file_name
    filename = params[:filename] || file.original_name || (asset.respond_to?(:label) && asset.label) || file.id
    file_parts = filename.split('.')
    existing_extension = file_parts.length > 1 ? file_parts.last : nil
    vocab_extension = MimeTypeService.label(file.mime_type)
    if vocab_extension.nil? || existing_extension == vocab_extension
      filename
    else
      "#{filename}.#{vocab_extension}"
    end
  end
end
