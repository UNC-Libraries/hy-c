# frozen_string_literal: true
# Ensure that required environment variables are loaded prior to initializers that use them
Rails.logger.debug('[ImageProcessor] Ensure environment variables are loaded prior to initializers')

# Rails 7 uses Zeitwerk for auto-loading, which can't always resolve app/ constants this early
# in the boot process. Explicitly requiring the file here ensures it's loaded before we call it.
require Rails.root.join('app/services/ensure_environment_service')
EnsureEnvironmentService.check_environment
