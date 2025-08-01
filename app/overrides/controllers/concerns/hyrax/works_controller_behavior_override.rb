# frozen_string_literal: true
# [hyc-override] https://github.com/samvera/hyrax/blob/hyrax-v4.0.0/app/controllers/concerns/hyrax/works_controller_behavior.rb
Hyrax::WorksControllerBehavior.module_eval do
  # [hyc-override] Add in missing xml and dc_xml extensions that are linked in the atom feed but not exposed by hyrax
  alias_method :original_additional_response_formats, :additional_response_formats
  def additional_response_formats(format)
    original_additional_response_formats(format)
    format.dc_xml { render body: presenter.export_as_oai_dc_xml, mime_type: Mime[:xml] }
    format.xml { render body: presenter.export_as_oai_dc_xml, mime_type: Mime[:xml] }
  end

  def available_admin_sets
    # only returns admin sets in which the user can deposit
    admin_set_results = Hyrax::AdminSetService.new(self).search_results(:deposit)

    # [hyc-override] for admin users, return permissions indicating they can do anything within the admin set
    if current_ability.admin?
      templates = admin_set_results.map { |admin_set| AdminPermissionTemplate.new(source_id: admin_set.id) }.to_a
    else
      # get all the templates at once, reducing query load
      templates = Hyrax::PermissionTemplate.where(source_id: admin_set_results.map(&:id)).to_a
    end

    admin_sets = admin_set_results.map do |admin_set_doc|
      template = templates.find { |temp| temp.source_id == admin_set_doc.id.to_s }

      # determine if sharing tab should be visible
      sharing = can?(:manage, template) || !!template&.active_workflow&.allows_access_grant?

      Hyrax::AdminSetSelectionPresenter::OptionsEntry
        .new(admin_set: admin_set_doc, permission_template: template, permit_sharing: sharing)
    end

    Hyrax::AdminSetSelectionPresenter.new(admin_sets: admin_sets)
  end

  private
  # [hyc-override] Capture whether the work had an embargo before changes are saved
  alias_method :original_save_permissions, :save_permissions
  def save_permissions
    original_save_permissions
    @original_embargo_state = curation_concern.under_embargo?
  end

  # [hyc-override] Return true if the permissions have changed or the embargo state has changed
  alias_method :original_permissions_changed?, :permissions_changed?
  def permissions_changed?
    original_permissions_changed? || @original_embargo_state != curation_concern.under_embargo?
  end

  # [hyc-override] Special permissions for admins indicating they aren't constrained by the admin set
  class AdminPermissionTemplate < Hyrax::PermissionTemplate
    def release_no_delay?
      false
    end

    def release_before_date?
      false
    end

    def release_date
      nil
    end

    def visibility
      nil
    end
  end
end
