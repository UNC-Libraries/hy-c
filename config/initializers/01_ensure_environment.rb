# frozen_string_literal: true
# Ensure that required environment variables are loaded prior to initializers that use them
Rails.logger.debug('[ImageProcessor] Ensure environment variables are loaded prior to initializers')

EnsureEnvironmentService.check_environment
