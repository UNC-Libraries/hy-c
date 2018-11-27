module Hyrax
  module Workflow
    class PendingDeletionNotification < AbstractNotification
      private

      def subject
        I18n.t('hyrax.notifications.workflow.deletion_pending.subject')
      end

      def message
        I18n.t('hyrax.notifications.workflow.deletion_pending.message', title: title, work_id: work_id,
               document_path: document_path, user: user, comment: comment)
      end

      def users_to_notify
        super << user
      end
    end
  end
end
