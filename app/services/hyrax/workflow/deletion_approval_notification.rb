# [hyc-override] Overriding  in hyrax to change email text
module Hyrax
  module Workflow
    class DeletionApprovalNotification < AbstractNotification
      private

      def subject
        'CDR deletion request has been approved'
      end

      def message
        "Your request to delete #{title} (#{link_to work_id, document_path}) has been approved by the
        Carolina Digital Repository (CDR). Please note that the information about your work will still be available
        publicly, but the files have been removed.\n\n
        Please contact the CDR at <a href=\"mailto:cdr@unc.edu\">cdr@unc.edu</a> if you have any questions."
      end

      def users_to_notify
        user_key = ActiveFedora::Base.find(work_id).depositor
        super << ::User.find_by(email: user_key)
      end
    end
  end
end
