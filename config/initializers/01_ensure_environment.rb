# Ensure that required environment variables are loaded prior to initializers that use them
Rails.logger.debug('[ImageProcessor] Ensure environment variables are loaded prior to initializers')
# if Rails.env.development?
%w[SECRET_KEY_BASE
   SOLR_PRODUCTION_URL
   FEDORA_PRODUCTION_URL
   FEDORA_BINARY_STORAGE
   FITS_LOCATION
   DEFAULT_ADMIN_SET
   DATABASE_URL
   HYRAX_HOST
   EMAIL_FROM_ADDRESS
   EMAIL_GEONAMES_ERRORS_ADDRESS
   DATABASE_AUTH
   SSO_LOGIN_PATH
   SSO_LOGOUT_URL
   DATA_STORAGE
   TEMP_STORAGE
   DERIVATIVE_STORAGE
   DROPBOX_APP_KEY
   DROPBOX_APP_SECRET
   GEONAMES_USER
   LONGLEAF_BASE_COMMAND
   LONGLEAF_STORAGE_PATH
   DELETED_PEOPLE_FILE
   ALLOW_NOTIFICATIONS
   DOI_PREFIX
   DATACITE_USER
   DATACITE_PASSWORD
   DOI_TEST_PREFIX
   DATACITE_TEST_USER
   DATACITE_TEST_PASSWORD
   HYRAX_DATABASE_PASSWORD
   IMAGE_PROCESSOR].each do |env_var|
  next unless !ENV.key?(env_var) || ENV[env_var].blank?

  Rails.logger.warn("Environment variable #{env_var} has not been set")
end
# end
