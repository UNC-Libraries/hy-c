# [hyc-override] Overriding in hyrax to change email text
module Hyrax
  module Workflow
    class PendingReviewNotification < AbstractNotification
      private

      def subject
        'CDR deposit needs review'
      end

      def message
        "#{title} (#{link_to work_id, document_path}) was deposited by #{user.user_key} and is awaiting your review.\n\n
        To review the work, click on the link above. You may need to sign into the CDR by clicking on the \"Login\"
        link in the upper right. Once you have decided to review or request changes, click the \"Review and Approval\"
        banner. Select an Action on the left, enter a comment if applicable, and click \"Submit\".\n\n
        For more information about the CDR's review process, please see the
        <a href=\"https://blogs.lib.unc.edu/cdr/index.php/frequently-asked-questions\">CDR FAQ</a>."
      end

      def users_to_notify
        super << user
      end
    end
  end
end