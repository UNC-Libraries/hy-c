# [devise-override] Overriding sessions controller to trigger shibboleth logout
class OmniauthController < Devise::SessionsController
  def new
    # Rails.logger.debug "SessionsController#new: request.referer = #{request.referer}"
    if Rails.env.production? && (ENV['DATABASE_AUTH'] == 'false')
      shib_login_url = ENV['SSO_LOGIN_PATH'] + "?target=#{user_shibboleth_omniauth_authorize_path}"
      redirect_to shib_login_url
    else
      super
    end
  end
end
