require 'mini_magick'

MiniMagick.configure do |config|
  config.shell_api = 'posix-spawn'
  Rails.logger.debug('[ImageProcessor] calling ImageService.processor from MiniMagick initializer')
  config.cli = ImageService.cli
end
