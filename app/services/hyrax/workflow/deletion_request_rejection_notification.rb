# [hyc-override] Overriding in hyrax to change email text
module Hyrax
  module Workflow
    class DeletionRequestRejectionNotification < AbstractNotification
      private

      def subject
        'Requested deletion was not approved'
      end

      def message
        "The deletion request for #{title} (#{link_to work_id, document_path}) was rejected by #{user.user_key}. #{comment}\n\n
        Please contact the CDR at <a href=\"mailto:cdr@unc.edu\">cdr@unc.edu</a> if you have any questions."
      end

      def users_to_notify
        user_key = ActiveFedora::Base.find(work_id).depositor
        super << ::User.find_by(email: user_key)
      end
    end
  end
end
