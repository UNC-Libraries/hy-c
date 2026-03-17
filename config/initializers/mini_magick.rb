# frozen_string_literal: true
require 'mini_magick'

# ImageService is autoloaded — configure cli after_initialize when it is available
MiniMagick.configure do |config|
  config.shell_api = 'posix-spawn'
end

Rails.application.config.after_initialize do
  Rails.logger.debug('[ImageProcessor] calling ImageService.processor from MiniMagick initializer')
  MiniMagick.configure { |config| config.cli = ImageService.cli }
end
