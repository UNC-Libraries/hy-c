class ApplicationController < ActionController::Base
  helper Openseadragon::OpenseadragonHelper
  # Adds a few additional behaviors into the application controller
  include Blacklight::Controller
  include Hydra::Controller::ControllerBehavior

  # Adds Hyrax behaviors into the application controller
  include Hyrax::Controller
  include Hyrax::ThemedLayoutController
  with_themed_layout '1_column'

  before_action :check_read_only, only: [:new, :create, :edit, :update, :destroy]

  # Redirect all deposit and edit requests with warning message when in read only mode
  def check_read_only
    return unless Flipflop.read_only?
    # Allows feature to be turned off
    return if self.class.to_s == Hyrax::Admin::StrategiesController.to_s
    redirect_back(
        fallback_location: root_path,
        alert: "The Carolina Digital Repository is in read-only mode for maintenance. No submissions or edits can be made at this time."
    )
  end

  # [hyc-override] Overriding default after_sign_in_path_for which only forward to the dashboard
  protected
    def after_sign_in_path_for(resource)
      direct_to = stored_location_for(resource) || request.env['omniauth.origin'] || root_path
      Rails.logger.debug "After sign in, direct to: #{direct_to}"
      direct_to
    end

  protect_from_forgery with: :exception
  skip_after_action :discard_flash_if_xhr
end
