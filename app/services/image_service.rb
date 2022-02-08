module ImageService
  # TODO: Once we're using GraphicsMagick across all environments, we should switch the default to GraphicsMagick
  def self.default_processor
    :imagemagick
  end

  def self.processor
    case ENV['IMAGE_PROCESSOR']
    when 'imagemagick'
      :imagemagick
    when 'graphicsmagick'
      :graphicsmagick
    else
      Rails.logger.warn("[ImageProcessor] The environment variable IMAGE_PROCESSOR should be set to either 'imagemagick' or 'graphicsmagick'. It is currently set to: #{ENV['IMAGE_PROCESSOR']}. Defaulting to using #{default_processor}")
      default_processor
    end
  end

  def self.cli
    case processor
    when :graphicsmagick
      Rails.logger.info('[ImageProcessor] Using GraphicsMagick as image processor')
      :graphicsmagick
    when :imagemagick
      Rails.logger.info('[ImageProcessor] Using ImageMagick as image processor')
      :imagemagick
    end
  end

  def self.external_convert_command
    case processor
    when :graphicsmagick
      Rails.logger.info('[ImageProcessor] Using GraphicsMagick for external_convert_command')
      'gm convert'
    when :imagemagick
      Rails.logger.info('[ImageProcessor] Using ImageMagick for external_convert_command')
      'convert'
    end
  end

  def self.external_identify_command
    case processor
    when :graphicsmagick
      Rails.logger.info('[ImageProcessor] Using GraphicsMagick for external_identify_command')
      'gm identify'
    when :imagemagick
      Rails.logger.info('[ImageProcessor] Using ImageMagick for external_identify_command')
      'identify'
    end
  end
end
