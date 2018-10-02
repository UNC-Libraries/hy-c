class AccountsController < ApplicationController
  before_action :ensure_admin!

  layout 'hyrax/dashboard'

  def new
  end

  def create
    notice = create_user(account_params[:onyen]).strip

    respond_to do |format|
      format.html { redirect_to hyrax.admin_users_path, notice: notice }
    end
  end

  private

  def account_params
    params.require(:account).permit(:onyen)
  end

  def ensure_admin!
    authorize! :read, :admin_dashboard
  end

  def create_user(onyen)
    email = "#{onyen}@ad.unc.edu"
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
