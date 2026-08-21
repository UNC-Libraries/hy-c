# frozen_string_literal: true
require_relative 'boot'

require 'logger'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Hyrax
  class Application < Rails::Application
    config.load_defaults 7.0

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.
    config.before_configuration do
      env_file = File.join(Rails.root, 'config', ENV['LOCAL_ENV_FILE'] || 'local_env.yml')
      env_vars = YAML.safe_load(File.read(env_file), aliases: true) || {}

      env_vars.each do |key, value|
        ENV[key.to_s] = value unless ENV.key?(key.to_s)
      end if File.exist?(env_file)
    end

    Rails.application.routes.default_url_options[:host] = ENV['HYRAX_HOST']

    # Explicitly set default locale
    config.i18n.default_locale = :en

    # Add custom error pages
    config.exceptions_app = self.routes

    # Configure logger
    config.log_formatter = proc do |severity, time, _progname, msg|
      "#{time} - #{severity}: #{msg}\n"
    end
    config.log_directory = ENV['LOG_DIRECTORY'] || 'log'
    log_path = ENV['LOGS_PATH'] || "log/#{Rails.env}.log"
    logger = ActiveSupport::Logger.new(log_path)
    logger.formatter = config.log_formatter
    config.logger = ActiveSupport::TaggedLogging.new(logger)

    # Prepend all log lines with the following tags.
    config.log_tags = [:request_id]

    # Load override files.
    # These files patch existing classes and do not define constants matching
    # their file paths, so they must be kept out of Zeitwerk autoloading.
    overrides_path = Rails.root.join('app/overrides').to_s
    Rails.autoloaders.main.ignore(overrides_path)
    config.to_prepare do
      Dir.glob("#{overrides_path}/**/*.rb").sort.each { |f| load f }
    end

    require_relative '../app/middleware/decode_query_string'
    config.middleware.insert_before Rack::Runtime, DecodeQueryString

    # active_fedora's railtie uses `<<` to append to autoload_paths, so we
    # duplicate the array before the railtie initializer runs.
    # This must be an initializer (not bare class-body code) so that `app.config`
    # returns the Engine::Configuration instance whose @autoload_paths attr_writer
    # is what the active_fedora.autoload initializer actually reads.
    initializer 'hy_c.unfreeze_autoload_paths', before: 'active_fedora.autoload' do |app|
      app.config.autoload_paths = app.config.autoload_paths.dup
    end
  end
end
