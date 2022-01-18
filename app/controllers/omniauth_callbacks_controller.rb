# [hyc-override] Overriding omniauth callbacks in devise gem for shibboleth integration
class OmniauthCallbacksController < Devise::OmniauthCallbacksController
  # Allow users to login when in read-only mode
  skip_before_action :check_read_only

  def shibboleth
    #Rails.logger.debug "OmniauthCallbacksController#shibboleth: request.env['omniauth.auth']: #{request.env['omniauth.auth']}"
    @user = User.from_omniauth(request.env['omniauth.auth'])
    if @user.persisted?
      set_flash_message :notice, :success, kind: 'Shibboleth'
      sign_in_and_redirect @user
    else
      session['devise.shibboleth_data'] = request.env['omniauth.auth']
      redirect_to root_path
    end
  end

  def failure
    set_flash_message! :alert, :failure, kind: OmniAuth::Utils.camelize(failed_strategy.name), reason: failure_message
    redirect_to root_path
  end
end
