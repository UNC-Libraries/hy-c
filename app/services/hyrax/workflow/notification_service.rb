# [hyc-override] Send workflow notifications to all admin set managers
module Hyrax
  module Workflow
    # Responsible for determining the appropriate notification(s) to deliver based on the given
    # criteria.
    class NotificationService
      # @api public
      #
      # For the given :entity and :action
      # - For each associated notification
      # - - Generate the type of notification
      # - - Expand the notification roles to users
      # - - Deliver the notification to the users
      # @param [Sipity::Entity] entity - the workflow entity
      # @param [Sipity::WorkflowAction] action - the action taken on the entity
      # @param [#comment] comment - the comment associated with the action being taken
      # @param [User] user - the person taking the action
      def self.deliver_on_action_taken(entity:, action:, comment:, user:)
        new(entity: entity,
            action: action,
            comment: comment,
            user: user).call
      end

      def initialize(entity:, action:, comment:, user:)
        @entity = entity
        @action = action
        @comment = comment
        @user = user
      end

      attr_reader :action, :entity, :comment, :user

      def call
        action.notifiable_contexts.each do |ctx|
          # send_notification(ctx.notification)
          Rails.logger.info "\nNot sending emails\n" # this should not be logged if emails are turned off in the env configs
        end
      end

      def send_notification(notification)
        notifier = notifier(notification)
        return unless notifier
        notifier.send_notification(entity: entity,
                                   comment: comment,
                                   user: user,
                                   recipients: recipients(notification))
      end

      # @return [Hash<String, Array>] a hash with keys being the strategy (e.g. "to", "cc") and
      #                               the values are a list of users.
      # [hyc-override] call new method for finding recipients
      def recipients(notification)
        notification.recipients.each_with_object({}) do |r, h|
          h[r.recipient_strategy] ||= []
          h[r.recipient_strategy] += find_recipients(entity, r.role)
        end
      end

      def notifier(notification)
        class_name = notification.name.classify
        klass = begin
          class_name.constantize
        rescue NameError
          Rails.logger.error "Unable to find '#{class_name}', so not sending notification"
          return nil
        end
        return klass if klass.respond_to?(:send_notification)
        Rails.logger.error "Expected '#{class_name}' to respond to 'send_notification', but it didn't, so not sending notification"
        nil
      end

      private

       # [hyc-override] new method for finding recipients based on users and groups
       def find_recipients(entity, role)
         users = []
         users += PermissionQuery.scope_users_for_entity_and_roles(entity: entity, roles: role)
         agents = PermissionQuery.scope_agents_associated_with_entity_and_role(entity: entity, role: role)
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
  end
end
