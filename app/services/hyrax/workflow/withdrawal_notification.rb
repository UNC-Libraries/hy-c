# frozen_string_literal: true
module Hyrax
  module Workflow
    # Same behavior as the DeletionApprovalNotification, except that the notification is also sent
    # to the instigating user
    class WithdrawalNotification < DeletionApprovalNotification
      private
      def users_to_notify
        users = []
        user_key = ActiveFedora::Base.find(work_id).depositor
        users << ::User.find_by(uid: user_key)
        users << @user
        users
      end
    end
  end
end
