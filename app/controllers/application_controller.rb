class ApplicationController < ActionController::Base
  helper Openseadragon::OpenseadragonHelper
  # Adds a few additional behaviors into the application controller
  include Blacklight::Controller
  include Hydra::Controller::ControllerBehavior

  # Adds Hyrax behaviors into the application controller
  include Hyrax::Controller
  include Hyrax::ThemedLayoutController
  with_themed_layout '1_column'

  # [hyc-override] Overriding default after_sign_in_path_for which only forwared to the dashboard
  protected
    def after_sign_in_path_for(resource)
      direct_to = stored_location_for(resource) || request.env['omniauth.origin'] || root_path
      Rails.logger.debug "After sign in, direct to: #{direct_to}"
      direct_to
    end

  protect_from_forgery with: :exception
  skip_after_action :discard_flash_if_xhr
end
