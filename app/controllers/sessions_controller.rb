# [devise-override] Overriding sessions controller to trigger shibboleth logout
class SessionsController < Devise::SessionsController
  def new
    if Rails.env.production? && (ENV['DATABASE_AUTH'] == 'false')
      redirect_to user_shibboleth_omniauth_authorize_path
    else
      super
    end
  end

  def after_sign_out_path_for(resource_or_scope)
    if Rails.env.production? && (ENV['DATABASE_AUTH'] == 'false')
      return ENV['SSO_LOGOUT_URL']
    else
      super
    end
  end
end
