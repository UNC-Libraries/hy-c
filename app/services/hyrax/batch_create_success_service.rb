# frozen_string_literal: true
# [hyc-override] Override to use translation file for email text
# [hyc-override] File can be deleted when upgrading to Hyrax 3.x
module Hyrax
  class BatchCreateSuccessService < AbstractMessageService
    attr_reader :user

    def initialize(user)
      @user = user
    end

    def message
      # [hyc-override] Override to use translation file for email text
      I18n.t('hyrax.notifications.batch_create_success.message', user: user)
    end

    def subject
      # [hyc-override] Override to use translation file for email text
      I18n.t('hyrax.notifications.batch_create_success.subject')
    end
  end
end
