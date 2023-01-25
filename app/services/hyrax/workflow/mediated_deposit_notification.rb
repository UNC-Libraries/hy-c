# frozen_string_literal: true
# Notification for non-honors mediated deposits. This file is not an override.
module Hyrax
  module Workflow
    class MediatedDepositNotification < AbstractNotification
      private

      def subject
        I18n.t('hyrax.notifications.workflow.mediated_deposit.subject')
      end

      def message
        I18n.t('hyrax.notifications.workflow.mediated_deposit.message', title: title, link: (link_to work_id, document_path))
      end

      def users_to_notify
        user_key = ActiveFedora::Base.find(work_id).depositor
        super << ::User.find_by(uid: user_key)
      end
    end
  end
end
