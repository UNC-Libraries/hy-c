class ApplicationController < ActionController::Base
  helper Openseadragon::OpenseadragonHelper
  # Adds a few additional behaviors into the application controller
  include HyraxHelper
  include Blacklight::Controller
  include Hydra::Controller::ControllerBehavior

  # Adds Hyrax behaviors into the application controller
  include Hyrax::Controller
  include Hyrax::ThemedLayoutController
  with_themed_layout '1_column'

  before_action :check_read_only, only: [:new, :create, :edit, :update, :destroy]
  before_action :check_redirect

  protect_from_forgery with: :exception
  skip_after_action :discard_flash_if_xhr
end
