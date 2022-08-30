# frozen_string_literal: true
module Hyrax
  module Workflow
    class DeletionRequestRejectionNotification < AbstractNotification
      private

      def subject
        I18n.t('hyrax.notifications.workflow.deletion_rejected.subject')
      end

      def message
        I18n.t('hyrax.notifications.workflow.deletion_rejected.message', title: title, work_id: work_id,
                                                                         document_path: document_path, user: user, comment: comment)
      end

      def users_to_notify
        user_key = ActiveFedora::Base.find(work_id).depositor
        super << ::User.find_by(uid: user_key)
      end
    end
  end
end
