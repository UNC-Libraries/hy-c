module Hyrax
  module Workflow
    class PendingDeletionNotification < AbstractNotification
      private

      def subject
        I18n.t('hyrax.notifications.workflow.deletion_pending.subject')
      end

      def message
        I18n.t('hyrax.notifications.workflow.deletion_pending.message', title: title, work_id: work_id,
                                                                        document_path: document_path, user: user, comment: comment)
      end

      def users_to_notify
        users = super
        users << user # requester
        users << ::User.find_by(uid: ActiveFedora::Base.find(work_id).depositor) # depositor
        repo_admins = Role.where(name: 'admin').first.users
        repo_admins.each do |u|
          users << u
        end
        users.uniq
      end
    end
  end
end
