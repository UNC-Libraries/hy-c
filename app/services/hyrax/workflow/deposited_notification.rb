# [hyc-override] Overriding in hyrax to change email text
module Hyrax
  module Workflow
    class DepositedNotification < AbstractNotification
      private

      def subject
        'CDR Deposit has been approved'
      end

      def message
        "#{title} (#{link_to work_id, document_path}) has been approved by #{user.user_key}. #{comment}.
        Your work will now be available in the CDR in accordance with the visibility settings that you selected."
      end

      def users_to_notify
        user_key = ActiveFedora::Base.find(work_id).depositor
        super << ::User.find_by(email: user_key)
      end
    end
  end
end
