# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/v3.4.2/app/controllers/hyrax/users_controller.rb
Hyrax::UsersController.class_eval do
  before_action :ensure_admin!, except: [:index] # [hyc-override] Overriding to restrict user profiles to admins
  before_action :authenticate_user! # [hyc-override] Overriding to restrict index to authenticated users. Needed to search for users

  # [hyc-override] Check that user is an admin
  def ensure_admin!
    authorize! :read, :admin_dashboard
  end
end
