# [hyc-override] https://github.com/samvera/hyrax/blob/hyrax-v4.0.0/app/controllers/concerns/hyrax/works_controller_behavior.rb
Hyrax::WorksControllerBehavior.module_eval do
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
