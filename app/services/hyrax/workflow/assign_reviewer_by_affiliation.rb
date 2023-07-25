# frozen_string_literal: true
module Hyrax::Workflow::AssignReviewerByAffiliation

  def self.call(target:, **)
    target.creators.each do |creator|
      creator['affiliation'].each do |affiliation|
        # Replace all non-alphanumeric characters, since postgres has a hard time with some punctuation
        department = affiliation.strip.to_s.downcase.gsub(/[^a-z0-9]+/, '_')
        reviewer = find_reviewer_for(department: department)
        permission_template_id = Hyrax::PermissionTemplate.find_by_source_id(target.admin_set_id).id

        workflow = Sipity::Workflow.where(permission_template_id: permission_template_id,
                                          active: true).first
        # Assign permissions to the departmental reviewer group.
        Hyrax::Workflow::PermissionGenerator.call(entity: target,
                                                  agents: [reviewer],
                                                  roles: ['viewing'],
                                                  workflow: workflow)
        group_name = "#{department}_reviewer"
        # This grants read access to the Fedora object.
        target.update permissions_attributes: [{ name: group_name, type: 'group', access: 'read' }]

        notify_reviewers(target,
                         target.id,
                         group_name,
                         'group',
                         'read')
      end
    end
  end

  # Send notification to reviewer group
  def self.notify_reviewers(work, work_id, group_name, type, access)
    # Find any users that are in the reviewer group
    recipients = Hash.new
    selected_role = Role.where(name: group_name).first
    recipients[:to] = selected_role.users

    # Return early if there aren't any users in the group
    return unless recipients[:to].count.positive?

    # Send notification to the users
    entity = Sipity::Entity.where(proxy_for_global_id: work.to_global_id.to_s).first
    depositor = User.find_by_user_key(work.depositor)
    Hyrax::Workflow::HonorsDepartmentReviewerDepositNotification.send_notification(entity: entity,
                                                                                   comment: nil,
                                                                                   user: depositor,
                                                                                   recipients: recipients)
  end

  def self.find_reviewer_for(department:)
    Role.where(name: "#{department}_reviewer").first_or_create
    Sipity::Agent.where(proxy_for_id: "#{department}_reviewer",
                        proxy_for_type: 'Hyrax::Group').first_or_create
  end
end
