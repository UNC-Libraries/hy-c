# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/v3.4.2/app/controllers/concerns/hyrax/controller.rb
module Hyrax::Controller
  extend ActiveSupport::Concern

  included do
    self.search_state_class = Hyrax::SearchState

    # Adds Hydra behaviors into the application controller
    include Hydra::Controller::ControllerBehavior
    # [hyc-override] added create_unrestricted_work_presenter as a replacement for deprecated create_work_presenter
    helper_method :create_unrestricted_work_presenter
    # helper_method :create_work_presenter # this is still present in hyrax 3, but the impl is in other controllers
    before_action :set_locale
    before_action :check_read_only, except: [:show, :index]

    class_attribute :search_service_class
    self.search_service_class = Hyrax::SearchService
  end

  # A presenter for selecting a work type to create, showing work types which are visible to non-admins.
  # Provided as a helper method for all pages.
  def create_unrestricted_work_presenter
    Hyrax::UnrestrictedSelectTypeListPresenter.new(current_ability.current_user)
  end


  # Provide a place for Devise to send the user to after signing in
  def user_root_path
    hyrax.dashboard_path
  end

  # Ensure that the locale choice is persistent across requests
  def default_url_options
    super.merge(locale: I18n.locale)
  end

  ##
  # @deprecated provides short-term compatibility with Blacklight 6
  # @return [Class<Blacklight::SearchBuilder>]
  def search_builder_class
    return super if defined?(super)
    Deprecation.warn('Avoid direct calls to `#search_builder_class`; this' \
                     ' method provides short-term compatibility to' \
                     ' Blacklight 6 clients.')
    blacklight_config.search_builder_class
  end

  ##
  # @deprecated provides short-term compatibility with Blacklight 6
  # @return [Blacklight::AbstractRepository]
  def repository
    return super if defined?(super)
    Deprecation.warn('Avoid direct calls to `#repository`; this method' \
                     ' provides short-term compatibility to Blacklight 6 ' \
                     ' clients.')
    blacklight_config.repository
  end

  # @note for Blacklight 6/7 compatibility
  def search_results(*args)
    return super if defined?(super) # use the upstream if present (e.g. in BL 6)

    search_service(*args).search_results
  end

  ##
  # @note for Blacklight 6/7 compatibility
  def search_service(**search_params)
    return super if defined?(super) && search_params.empty?

    search_service_class.new(config: blacklight_config,
                             scope: self,
                             user_params: search_params,
                             search_builder_class: search_builder_class)
  end

  private


  ##
  # @api public
  #
  # @return [#[]] a resolver for Hyrax's Transactions; this *should* be a
  #   thread-safe {Dry::Container}, but callers to this method should strictly
  #   use +#[]+ for access.
  #
  # @example
  #   transactions['change_set.create_work'].call(my_form)
  #
  # @see Hyrax::Transactions::Container
  # @see Hyrax::Transactions::Transaction
  # @see https://dry-rb.org/gems/dry-container
  def transactions
    Hyrax::Transactions::Container
  end

  # [hyc-override] Add begin/rescue for locale setting
  def set_locale
    I18n.locale = params[:locale] || I18n.default_locale
  rescue I18n::InvalidLocale
    I18n.locale = I18n.default_locale
  end

  # Called by Hydra::Controller::ControllerBehavior when CanCan::AccessDenied is caught
  # @param [CanCan::AccessDenied] exception error to handle
  def deny_access(exception)
    # For the JSON message, we don't want to display the default CanCan messages,
    # just custom Hydra messages such as "This item is under embargo.", etc.
    json_message = exception.message if exception.is_a? Hydra::AccessDenied
    if current_user&.persisted?
      deny_access_for_current_user(exception, json_message)
    else
      deny_access_for_anonymous_user(exception, json_message)
    end
  end

  def deny_access_for_current_user(exception, json_message)
    respond_to do |wants|
      wants.html do
        if [:show, :edit, :create, :update, :destroy].include? exception.action
          render 'hyrax/base/unauthorized', status: :unauthorized
        else
          redirect_to main_app.root_url, alert: exception.message
        end
      end
      wants.json { render_json_response(response_type: :forbidden, message: json_message) }
    end
  end

  def deny_access_for_anonymous_user(exception, json_message)
    session['user_return_to'] = request.url
    respond_to do |wants|
      wants.html { redirect_to main_app.new_user_session_path, alert: exception.message }
      wants.json { render_json_response(response_type: :unauthorized, message: json_message) }
    end
  end

  # Redirect all deposit and edit requests with warning message when in read only mode
  def check_read_only
    return unless Flipflop.read_only?
    # Allows feature to be turned off
    return if self.class.to_s == Hyrax::Admin::StrategiesController.to_s
    redirect_to root_path, flash: { error: t('hyrax.read_only') }
  end
end
