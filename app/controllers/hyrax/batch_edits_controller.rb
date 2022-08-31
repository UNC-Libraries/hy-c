# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/v2.9.6/app/controllers/hyrax/batch_edits_controller.rb
# Since this is a controller, moving it to the overrides directory causes some expectations to fail
module Hyrax
  class BatchEditsController < ApplicationController
    # [hyc-override] Disallow batch operations from anyone, including admins
    before_action :no_batch_operations

    def no_batch_operations
      # For the moment we'll block all users
      # return if current_user.admin?
      redirect_back(
        fallback_location: root_path,
        alert: 'Batch operations are not allowed.'
      )
    end
  end
end
