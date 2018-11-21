require 'cgi'
# [hyc-override] Overriding sessions controller in devise gem to trigger shibboleth logout
class OmniauthController < Devise::SessionsController
  # Allow all search options when in read-only mode
  skip_before_action :check_read_only

  def new
    # Rails.logger.debug "SessionsController#new: request.referer = #{request.referer}"
    if Rails.env.production? && (ENV['DATABASE_AUTH'] == 'false')
      origin_param = CGI.escape("&origin=#{request.referer}")
      shib_login_url = ENV['SSO_LOGIN_PATH'] + "?target=#{user_shibboleth_omniauth_authorize_path}#{origin_param}"
      redirect_to shib_login_url
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
