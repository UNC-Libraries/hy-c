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
  before_action :check_redirect

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

  # Can be removed if we no longer need redirects
  def check_redirect
    # Base redirect for Box-C uuid links
    full_path = request.url
    path_parts = request.url.split('uuid:')
    request_host = "#{request.protocol}#{request.host}"

    if request_host =~ /localhost/
      request_host = "#{request_host}:#{request.port}"
    end

    # Base redirect for Hy-C uuid links
    if path_parts.length > 1
      uuid = path_parts[1]
      redirect_uuids = File.read(Rails.root.join('lib', 'redirects', 'redirect_uuids.csv'))
      csv = CSV.parse(redirect_uuids, headers: true)
      redirect_path = csv.find { |row| row['uuid'] == uuid }

      # Should correctly redirect record, indexablecontent (download) paths
      if redirect_path # Redirect to Hy-C
        updated_path = "#{request_host}/concern/#{redirect_path['new_path']}"
        Rails.logger.info "In hy-c uuid redirect match: #{updated_path}"
        redirect_to updated_path, status: :moved_permanently
      elsif full_path =~ /search.*?uuid/ # All Box-C searches with uuids should go to the 404 page
        updated_path = "#{request_host}/concern/404"
        Rails.logger.info "Is box-c search with uuid: #{updated_path}"
        redirect_to updated_path, status: :moved_permanently
      elsif full_path =~ /work|record|indexablecontent/ # Redirect to Box-C
        path_rewrite = full_path.gsub(/cdr\./, 'dcr.')
        Rails.logger.info "Still in box-c: #{path_rewrite}"
        redirect_to path_rewrite, status: :moved_permanently
      else # Redirect to Hy-C homepage
        Rails.logger.info "box-c fall through to hy-c homepage: #{request_host}"
        redirect_to request_host, status: :moved_permanently
      end
    end

    # All Box-C searches not caught above should go to the 404 page
    if full_path =~ /search\?/
      Rails.logger.info "Is box-c search: #{request_host}/concern/404"
      redirect_to "#{request_host}/concern/404", status: :moved_permanently
    end

    Rails.logger.info "Fall through to original path: #{full_path}"
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
