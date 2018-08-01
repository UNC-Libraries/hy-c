class AccountsController < ApplicationController
  before_action :ensure_admin!

  layout 'hyrax/dashboard'

  def new
  end

  def create
    notice = create_user(account_params[:email])

    respond_to do |format|
      format.html { redirect_to hyrax.admin_users_path, notice: notice }
    end
  end

  private

  def account_params
    params.require(:account).permit(:email)
  end

  def ensure_admin!
    authorize! :read, :admin_dashboard
  end

  def create_user(email)
    onyen = email.split('@').first
    if User.where(uid: onyen).blank?
      user = User.where(provider: 'shibboleth', uid: onyen, email: email).first_or_create
      user.display_name = onyen
      user.save
      "A user account for #{email} has been created."
    else
      "A user account for #{email} already exists."
    end
  end
end
