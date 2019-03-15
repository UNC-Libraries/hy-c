# [hyc-override] Override to use translation file for email text
# [hyc-override] File can be deleted when upgrading to Hyrax 3.x
module Hyrax
  module Workflow
    class DepositedNotification < AbstractNotification
      private

      def subject
        I18n.t('hyrax.notifications.workflow.deposited.subject')
      end

      def message
        I18n.t('hyrax.notifications.workflow.deposited.message', title: title, link: (link_to work_id, document_path))
      end

      def users_to_notify
        user_key = ActiveFedora::Base.find(work_id).depositor
        super << ::User.find_by(uid: user_key)
      end
    end
  end
end
