module Hyrax
  module Workflow
    class DepositSubmittedNotification < AbstractNotification
      private

      def subject
        I18n.t('hyrax.notifications.workflow.deposited_for_review.subject')
      end

      def message
        I18n.t('hyrax.notifications.workflow.deposited_for_review.message', title: title, link: (link_to work_id, document_path))
      end

      def users_to_notify
        user_key = ActiveFedora::Base.find(work_id).depositor
        super << ::User.find_by(email: user_key)
      end
    end
  end
end