# Ensure that required environment variables are loaded prior to initializers that use them
Rails.logger.debug('[ImageProcessing] Ensure environment variables are loaded prior to initializers')
# if Rails.env.development?
%w[
  IMAGE_PROCESSOR
].each do |env_var|

  next unless !ENV.key?(env_var) || ENV[env_var].blank?

  raise <<~MESSAGE
    Missing environment variable: #{env_var}

    Ask a teammate for the appropriate value.
  MESSAGE
end
# end
