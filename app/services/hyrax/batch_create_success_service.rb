# [hyc-override] Overriding  in hyrax to change email text
module Hyrax
  class BatchCreateSuccessService < AbstractMessageService
    attr_reader :user

    def initialize(user)
      @user = user
    end

    def message
      message = "Hello,\n\n"
      message += "Your batch of works has been successfully deposited to the Carolina Digital Repository (CDR). "
      message += "To edit the batch, go to your #{link_to 'Works Dashboard', main_app.my_dashboard_works_facet_path(user.id)} in the CDR. "
    end

    def subject
      'CDR batch deposit successful'
    end
  end
end