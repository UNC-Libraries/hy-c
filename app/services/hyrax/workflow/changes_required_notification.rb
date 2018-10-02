# [hyc-override] Overriding  in hyrax to change email text
module Hyrax
  module Workflow
    class ChangesRequiredNotification < AbstractNotification
      private

      def subject
        'CDR deposit requires changes'
      end

      def message
        "#{title} (#{link_to work_id, document_path}) requires the following changes before approval.\n\n '#{comment}'\n\n
        Click on the link above to view and edit the work. You may need to sign into the CDR by clicking on the \"Login\"
        link in the upper right. When you are finished, click on the \"Review and Approval\" banner, select \"Request Review\"
        and click the \"Submit\" button to resubmit your paper to your designated reviewer.\n\n
        If you have questions about the review process, email <a href=\"mailto:cdr@unc.edu\">cdr@unc.edu</a>. Questions about
        the reviewer comments should be directed to your reviewer."
      end

      def users_to_notify
        user_key = document.depositor
        super << ::User.find_by(email: user_key)
      end
    end
  end
end