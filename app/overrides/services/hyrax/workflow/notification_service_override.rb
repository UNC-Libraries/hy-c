# frozen_string_literal: true
# app/services/hyrax/workflow/notification_service.rb
# https://github.com/samvera/hyrax/blob/main/app/services/hyrax/workflow/notification_service.rb
Hyrax::Workflow::NotificationService.class_eval do
  # @return [Hash<String, Array>] a hash with keys being the strategy (e.g. "to", "cc") and
  #                               the values are a list of users.
  # [hyc-override] call new method for finding recipients
  def recipients(notification)
    notification.recipients.each_with_object({}) do |r, h|
      h[r.recipient_strategy] ||= []
      h[r.recipient_strategy] += find_recipients(entity, r.role)
    end
  end

  # new method for finding recipients based on users and groups
  def find_recipients(entity, role)
    users = []
    users += Hyrax::Workflow::PermissionQuery.scope_users_for_entity_and_roles(entity: entity, roles: role)
    agents = Hyrax::Workflow::PermissionQuery.scope_agents_associated_with_entity_and_role(entity: entity, role: role)
    agents.each do |agent|
      # Notifications for all workflow state changes will still go to the admin set owner, but not to all admins
      if (agent.proxy_for_type == 'Hyrax::Group' || agent.proxy_for_type == 'Role') && role.name != 'depositing' &&
         agent.proxy_for_id != 'registered' && agent.proxy_for_id != 'admin'
        users += Role.where(name: agent.proxy_for_id).first.users
      elsif agent.proxy_for_type == 'User'
        users << ::User.find(agent.proxy_for_id)
      end
    end

    users.uniq
  end
end
