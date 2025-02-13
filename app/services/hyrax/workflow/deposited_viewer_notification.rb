# frozen_string_literal: true
module Hyrax
  module Workflow
    # This notification service was created to exclusively notify viewers in the viewer-specific workflow.
    # Using the DepositedManagerNotificaiton class for this would send deposit notifications to managers as well.
    class DepositedViewerNotification < AbstractNotification
      private

      def subject
        I18n.t('hyrax.notifications.workflow.deposited_manager.subject')
      end

      def message
        I18n.t('hyrax.notifications.workflow.deposited_manager.message', title: title, link: (link_to work_id, document_path))
      end

      def users_to_notify
        all_recipients = recipients.fetch(:to, []) + recipients.fetch(:cc, [])
        all_recipients.uniq

        users_and_roles = Sipity::Entity.where(workflow_id: @entity.workflow_id)
                    .joins('INNER JOIN sipity_workflow_roles ON sipity_workflow_roles.workflow_id = sipity_entities.workflow_id')
                    .joins('INNER JOIN sipity_workflow_responsibilities ON sipity_workflow_responsibilities.workflow_role_id = sipity_workflow_roles.id')
                    .joins('INNER JOIN sipity_roles ON sipity_roles.id = sipity_workflow_roles.role_id')
                    .joins('INNER JOIN sipity_agents ON sipity_agents.id = sipity_workflow_responsibilities.agent_id')
                    .where(sipity_roles: { name: ['managing', 'viewing'] })  # Filters results by role name
                    .select('sipity_agents.proxy_for_id, sipity_roles.name AS role_name')

        user_role_map = users_and_roles.each_with_object({}) do |record, h|
          user_id = record.proxy_for_id.to_i
          h[user_id] ||= Set.new
          h[user_id] << record.role_name
        end

        exclusively_viewers = user_role_map.select { |k, v| v.include?('viewing') && !v.include?('managing') }
        all_recipients.select { |r| r.id.in?(exclusively_viewers.keys) }
      end
    end
  end
end
