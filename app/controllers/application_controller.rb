# frozen_string_literal: true
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
  before_action :replace_invalid_f_parameter

  protect_from_forgery with: :exception

  # Catch various page not found and bad request exceptions
  rescue_from ActionController::RoutingError, with: :render_404
  rescue_from Riiif::ImageNotFoundError, with: :render_riiif_404
  rescue_from Blacklight::Exceptions::RecordNotFound, with: :render_404
  rescue_from Hyrax::ObjectNotFoundError, with: :render_404
  rescue_from BlacklightRangeLimit::InvalidRange, with: :render_400
  rescue_from Ldp::Gone, with: :render_404
  rescue_from ActiveFedora::ObjectNotFoundError, with: :render_404
  rescue_from ActionController::InvalidAuthenticityToken, with: :render_401
  rescue_from ActionController::UnknownFormat, with: :render_404
  rescue_from Riiif::ConversionError, with: :render_400
  rescue_from Faraday::TimeoutError, with: :render_408
  rescue_from ArgumentError, with: :render_400
  rescue_from URI::InvalidURIError, with: :render_400

  protected

  def render_400
    render 'errors/not_found', status: 400, formats: :html
  end

  def render_401
    render 'errors/not_found', status: 401, formats: :html
  end

  def render_riiif_404
    render_json_response(response_type: :not_found)
  end

  def render_json_response(response_type: :success, message: nil, options: {})
    json_body = Hyrax::API.generate_response_body(response_type: response_type, message: message, options: options)
    render json: json_body, status: response_type
  end

  def render_404
    render 'errors/not_found', status: 404, formats: :html, layout: 'layouts/hyrax/1_column'
  end

  def render_408
    head :request_timeout
  end

  def render_500
    render 'errors/internal_server_error', status: 500, formats: :html
  end

  # Error caught in catalogController
  def render_rsolr_exceptions(exception)
    exception_text = exception.to_s

    if exception_text.include?('java.lang.NumberFormatException') ||
      exception_text.include?("Can't determine a Sort Order")
      render_400
    else
      render_404
    end
  end

  # [hyc-override] Overriding default after_sign_in_path_for which only forward to the dashboard
  def after_sign_in_path_for(resource)
    direct_to_path = direct_to(resource)
    Rails.logger.debug "After sign in, direct to: #{direct_to_path}"
    direct_to_path
  end

  private

  def direct_to(resource)
    stored_location = stored_location_for(resource)
    return stored_location if stored_location.present?
    return root_path if params['origin'].nil?
    return params['origin'] if URI.parse(params['origin']).host == request.env['SERVER_NAME']

    root_path
  rescue URI::InvalidURIError
    root_path
  end

  # Redirect all deposit and edit requests with warning message when in read only mode
  def check_read_only
    return unless Flipflop.read_only?
    # Allows feature to be turned off
    return if self.class.to_s == Hyrax::Admin::StrategiesController.to_s

    redirect_back(
      fallback_location: root_path,
      alert: 'The Carolina Digital Repository is in read-only mode for maintenance. No submissions or edits can be made at this time.'
    )
  end

  # Can be removed if we no longer need redirects
  def check_redirect
    # Base redirect for Box-C uuid links
    full_path = request.original_fullpath
    request_host = "#{request.protocol}#{request.host}"

    request_host = "#{request_host}:#{request.port}" if request_host =~ /localhost/

    uuid = full_path[/uuid:([a-f0-9\-]+)/, 1]

    # Base redirect for Hy-C uuid links
    unless uuid.nil? || request_host.match(ENV['REDIRECT_NEW_DOMAIN']) # prevent infinite redirects in tests
      redirect_path = BoxcToHycRedirectService.redirect_lookup('uuid', uuid)

      # Should correctly redirect record, indexablecontent (download) paths
      if redirect_path # Redirect to Hy-C
        updated_path = "#{request_host}/concern/#{redirect_path['new_path']}"
        Rails.logger.info "In hy-c uuid redirect match: #{updated_path}"
        redirect_to updated_path, status: :moved_permanently
      elsif full_path.starts_with?('/search', '/listContent') # All Box-C searches with uuids should go to the 404 page
        updated_path = "#{request_host}/concern/404"
        Rails.logger.info "Forwarding Box-c search to 404, user requested #{full_path}"
        redirect_to updated_path, status: :moved_permanently
      elsif full_path.starts_with?('/content', '/list', '/record', '/indexablecontent') # Redirect to Box-C
        path_rewrite = request.url.gsub(/https\:\/\/#{ENV['REDIRECT_OLD_DOMAIN']}/, "https://#{ENV['REDIRECT_NEW_DOMAIN']}")
        Rails.logger.info "Still in box-c: #{path_rewrite}"
        redirect_to path_rewrite, status: :moved_permanently
      else # Redirect to Hy-C homepage
        Rails.logger.info "box-c fall through to hy-c homepage: #{request_host}"
        redirect_to request_host, status: :moved_permanently
      end

      return
    end

    # All Box-C searches not caught above should go to the 404 page
    if full_path.starts_with?('/search?')
      Rails.logger.info "Is box-c search: #{request_host}/concern/404"
      redirect_to "#{request_host}/concern/404", status: :moved_permanently

      return
    end

    Rails.logger.debug "Fall through to original path: #{request.url}"
  end

  # Replace the blacklight filter field param with an empty Parameters object if
  # the current value
  def replace_invalid_f_parameter
    if params[:f].nil? || params[:f].is_a?(ActionController::Parameters)
      return
    end
    Rails.logger.warn('Overriding invalid filter field value')
    params[:f] = ActionController::Parameters.new({})
  end
end
