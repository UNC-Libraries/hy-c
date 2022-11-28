# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/v3.4.2/app/helpers/hyrax/file_set_helper.rb
Hyrax::FileSetHelper.module_eval do
  ##
  # @todo inline the "workflow restriction" into the `can?(:download)` check.
  #
  # @param file_set [#id]
  #
  # @return [Boolean] whether to display the download link for the given file
  #   set
  # [hyc-override] reworked to include admin permissions and workflow adjustments
  def display_media_download_link?(file_set:)
    # Make sure download links are enabled for the app
    return false if !Hyrax.config.display_media_download_link?
    # Always permit admin users
    return true if current_user&.admin?
    parent_obj = file_set.try(:parent)
    # Reject for non-admins if deleted or withdrawn
    if parent_obj.respond_to?('workflow') &&
        parent_obj.workflow.in_workflow_state?(['withdrawn', 'pending deletion'])
      return false
    end
    # Reject if embargoed
    return false if file_set.embargo_release_date.present?
    # Make sure the user has permission to download the fileset
    return false if !can?(:download, file_set)
    # if there are no workflow restrictions on the parent, return true
    !workflow_restriction?(parent_obj)
  end
end
