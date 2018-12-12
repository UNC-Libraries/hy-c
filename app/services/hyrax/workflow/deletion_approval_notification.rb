module Hyrax
  module Workflow
    class DeletionApprovalNotification < AbstractNotification
      private

      def subject
        I18n.t('hyrax.notifications.workflow.deletion_approved.subject')
      end

      def message
        I18n.t('hyrax.notifications.workflow.deletion_approved.message', title: title, work_id: work_id,
               document_path: document_path, user: user, comment: comment)
      end

      def users_to_notify
        user_key = ActiveFedora::Base.find(work_id).depositor
        super << ::User.find_by(email: user_key)
      end
    end
  end
end
