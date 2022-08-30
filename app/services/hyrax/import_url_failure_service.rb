# frozen_string_literal: true
# [hyc-override] Override to use translation file for email text
# [hyc-override] File can be deleted when upgrading to Hyrax 3.x
module Hyrax
  class ImportUrlFailureService < AbstractMessageService
    def message
      file_set.errors.full_messages.join(', ')
    end

    def subject
      # [hyc-override] Override to use translation file for email text
      I18n.t('hyrax.notifications.import_url_failure.subject')
    end
  end
end
