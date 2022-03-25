# This module ensures that all expected environment variables are present, based on whether the application is being run
# in test, development, or production mode.
module EnsureEnvironmentService
  def self.check_environment
    return unless expected_variables.present?

    expected_variables.each do |env_var|
      next unless !ENV.key?(env_var) || ENV[env_var].blank?

      Rails.logger.warn("Environment variable #{env_var} has not been set")
    end
  end

  def self.expected_variables
    if Rails.env&.production?
      prod_only + shared
    # Right now it appears that test and development expect the same environment variables
    elsif Rails.env&.development? || Rails.env&.test?
      dev_only + shared
    else
      Rails.logger.warn('Cannot determine required environment variables, application may not work as expected.')
    end
  end

  def self.shared
    %w[ALLOW_NOTIFICATIONS
       CLAMD_TCP_HOST
       DATABASE_AUTH
       DATABASE_URL
       DATACITE_PASSWORD
       DATACITE_USER
       DATA_STORAGE
       DEFAULT_ADMIN_SET
       DELETED_PEOPLE_FILE
       DERIVATIVE_STORAGE
       DROPBOX_APP_KEY
       DROPBOX_APP_SECRET
       EMAIL_FROM_ADDRESS
       EMAIL_GEONAMES_ERRORS_ADDRESS
       FEDORA_BINARY_STORAGE
       FEDORA_PRODUCTION_URL
       FITS_LOCATION
       GEONAMES_USER
       HYRAX_DATABASE_PASSWORD
       HYRAX_HOST
       IMAGE_PROCESSOR
       LOG_LEVEL
       LONGLEAF_BASE_COMMAND
       LONGLEAF_STORAGE_PATH
       SECRET_KEY_BASE
       SOLR_PRODUCTION_URL
       SSO_LOGIN_PATH
       SSO_LOGOUT_URL
       TEMP_STORAGE]
  end

  def self.prod_only
    %w[DATACITE_PREFIX
       DATACITE_USE_TEST_API
       GOOGLE_ANALYTICS_ID
       GOOGLE_OAUTH_APP_NAME
       GOOGLE_OAUTH_APP_VERSION
       GOOGLE_OAUTH_CLIENT_EMAIL
       GOOGLE_OAUTH_PRIVATE_KEY_PATH
       GOOGLE_OAUTH_PRIVATE_KEY_SECRET
       LOGS_PATH
       NOINDEX
       RAILS_MAX_THREADS
       REDIRECT_FILE_PATH
       REDIRECT_NEW_DOMAIN
       REDIRECT_OLD_DOMAIN]
  end

  def self.dev_only
    %w[DATACITE_TEST_PASSWORD
       DATACITE_TEST_USER
       DOI_TEST_PREFIX
       DOI_PREFIX
       FEDORA_DEV_URL
       REDIS_HOST
       REDIS_URL
       SOLR_DEV_URL]
  end
end
