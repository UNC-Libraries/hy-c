module Hyrax
  module Workflow
    class HonorsDepartmentReviewerDepositNotification < AbstractNotification
      private

      def subject
        I18n.t('hyrax.notifications.workflow.honors_department_reviewer_deposit.subject')
      end

      def message
        I18n.t('hyrax.notifications.workflow.honors_department_reviewer_deposit.message', title_link: (link_to title, document_path))
      end

      def users_to_notify
        super
      end
    end
  end
end
