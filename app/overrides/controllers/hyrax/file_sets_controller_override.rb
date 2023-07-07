# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/3.5/app/controllers/hyrax/file_sets_controller.rb

Hyrax::FileSetsController.class_eval do
  # [hyc-override] Only allow deletions by admins
  before_action :ensure_admin!, only: :destroy

  private

  def ensure_admin!
    authorize! :read, :admin_dashboard
  end
end
