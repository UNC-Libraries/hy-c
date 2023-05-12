# frozen_string_literal: true
# https://github.com/samvera/hyrax/blame/hyrax-v3.5.0/app/services/hyrax/workflow/pending_review_notification.rb
Hyrax::Workflow::PendingReviewNotification.class_eval do
  private
    # [hyc-override] Don't add the instigating user into list of users to notify
    def users_to_notify
      super
    end
end
