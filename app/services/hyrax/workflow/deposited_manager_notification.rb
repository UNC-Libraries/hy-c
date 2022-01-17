module Hyrax
  module Workflow
    # This notification service was created to allow some admin set managers to get notifications.
    # Using the default DepositedNotificaiton class for this would send deposit notifications
    # to all managers in all workflows instead of just in the manager-specific workflow.
    class DepositedManagerNotification < AbstractNotification
      private

      def subject
        I18n.t('hyrax.notifications.workflow.deposited_manager.subject')
      end

      def message
        I18n.t('hyrax.notifications.workflow.deposited_manager.message', title: title, link: (link_to work_id, document_path))
      end

      def users_to_notify
        super
      end
    end
  end
end
