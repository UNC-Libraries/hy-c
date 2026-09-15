# frozen_string_literal: true
require 'cgi'
# [hyc-override] Overriding sessions controller in devise gem to trigger shibboleth logout
class OmniauthController < Devise::SessionsController
  # Allow users to login when in read-only mode
  skip_before_action :check_read_only

  def new
    # Rails.logger.debug "SessionsController#new: request.referer = #{request.referer}"
    if Rails.env.production? && (AuthConfig.use_database_auth? == false)
      shib_query = "target=#{user_shibboleth_omniauth_callback_path}%26origin=#{CGI.escape(request.referrer.to_s)}"
      shib_login_url = ENV['SSO_LOGIN_PATH'] + "?#{shib_query}"
      redirect_to shib_login_url, allow_other_host: true
    else
      super
    end
  end

  def after_sign_out_path_for(resource_or_scope)
    if Rails.env.production? && (ENV['DATABASE_AUTH'] == 'false')
      ENV['SSO_LOGOUT_URL']
    else
      super
    end
  end

  protected

  # [hyc-override] Overriding Devise's default behavior to redirect to an external URL after sign out.
  # n Rails 7+, redirect_to requires allow_other_host: true for external hosts
  def respond_to_on_destroy
    respond_to do |format|
      format.all { head :no_content }

      format.any(*navigational_formats) do
        redirect_to(
          after_sign_out_path_for(resource_name),
          status: Devise.responder.redirect_status,
          allow_other_host: true
        )
      end
    end
  end
end
