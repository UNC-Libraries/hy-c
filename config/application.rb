# frozen_string_literal: true
require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Hyrax
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.
    config.before_configuration do
      env_file = File.join(Rails.root, 'config', ENV['LOCAL_ENV_FILE'] || 'local_env.yml')

      YAML.load(File.open(env_file)).each do |key, value|
        ENV[key.to_s] = value
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

    # Load override files
    overrides = "#{Rails.root}/app/overrides"
    config.to_prepare do
      Dir.glob("#{overrides}/**/*_override.rb").sort.each do |c|
        Rails.configuration.cache_classes ? require(c) : load(c)
      end
    end
  end
end
