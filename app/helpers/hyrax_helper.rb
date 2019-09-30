module HyraxHelper
  include ::BlacklightHelper
  include Hyrax::BlacklightOverride
  include Hyrax::HyraxHelperBehavior

  def language_links(options)
    begin
      to_sentence(options[:value].map { |lang| link_to LanguagesService.label(lang), main_app.search_catalog_path(f: { language_sim: [lang] })})
    rescue KeyError
      nil
    end
  end

  def language_links_facets(options)
    begin
      link_to LanguagesService.label(options), main_app.search_catalog_path(f: { language_sim: [options] })
    rescue KeyError
      options
    end
  end

  def redirect_lookup(column, id)
    if ENV.has_key?('REDIRECT_FILE_PATH') && File.exist?(ENV['REDIRECT_FILE_PATH'])
      redirect_uuids = File.read(ENV['REDIRECT_FILE_PATH'])
    else
      redirect_uuids = File.read(Rails.root.join('lib', 'redirects', 'redirect_uuids.csv'))
    end

    csv = CSV.parse(redirect_uuids, headers: true)
    csv.find { |row| row[column].match(id) }
  end

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
    full_path = request.original_fullpath
    request_host = "#{request.protocol}#{request.host}"

    if request_host =~ /localhost/
      request_host = "#{request_host}:#{request.port}"
    end

    uuid = full_path[/uuid:([a-f0-9\-]+)/, 1]

    # Base redirect for Hy-C uuid links
    unless uuid.nil?
      redirect_path = redirect_lookup('uuid', uuid)

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
        path_rewrite = request.url.gsub(/#{ENV['REDIRECT_OLD_DOMAIN']}\./, "#{ENV['REDIRECT_NEW_DOMAIN']}.")
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

  # [hyc-override] Overriding default after_sign_in_path_for which only forward to the dashboard
  protected
  def after_sign_in_path_for(resource)
    direct_to = stored_location_for(resource) || request.env['omniauth.origin'] || root_path
    Rails.logger.debug "After sign in, direct to: #{direct_to}"
    direct_to
  end
end
