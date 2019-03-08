module Hyrax
  module Workflow
    class VirusFoundNotification < AbstractNotification
      private

      def subject
        I18n.t('hyrax.notifications.workflow.virus_found.subject')
      end

      def message
        I18n.t('hyrax.notifications.workflow.virus_found.message', title: title, link: (link_to work_id, document_path),
               comment: comment)
      end

      def users_to_notify
        user_key = ActiveFedora::Base.find(work_id).depositor
        super << ::User.find_by(uid: user_key)
      end
    end
  end
end
