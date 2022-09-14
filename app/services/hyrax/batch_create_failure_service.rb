# frozen_string_literal: true
# [hyc-override] Override to use translation file for email text
# [hyc-override] File can be deleted when upgrading to Hyrax 3.x
module Hyrax
  class BatchCreateFailureService < AbstractMessageService
    attr_reader :user, :messages
    def initialize(user, messages)
      @user = user
      @messages = messages.to_sentence
    end

    def message
      # [hyc-override] Override to use translation file for email text
      I18n.t('hyrax.notifications.batch_create_failure.message', user: user, messages: messages)
    end

    def subject
      # [hyc-override] Override to use translation file for email text
      I18n.t('hyrax.notifications.batch_create_failure.subject')
    end
  end
end
