# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/3.5/app/controllers/hyrax/file_sets_controller.rb
# Since this is a controller, moving it to the overrides directory causes some expectations to fail

module Hyrax
  class FileSetsController < ApplicationController
    # [hyc-override] Only allow deletions by admins
    before_action :ensure_admin!, only: :destroy

    private

    def ensure_admin!
      authorize! :read, :admin_dashboard
    end
  end
end
