module Hyrax
  module Workflow
    class HonorsMediatedDepositNotification < AbstractNotification
      private

      def subject
        I18n.t('hyrax.notifications.workflow.honors_mediated_deposit.subject')
      end

      def message
        I18n.t('hyrax.notifications.workflow.honors_mediated_deposit.message', title_link: (link_to title, document_path))
      end

      def users_to_notify
        user_key = ActiveFedora::Base.find(work_id).depositor
        super << ::User.find_by(uid: user_key)
      end
    end
  end
end
