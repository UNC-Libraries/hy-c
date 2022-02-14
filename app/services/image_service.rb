module ImageService
  # TODO: Once we're using GraphicsMagick across all environments, we should switch the default to GraphicsMagick
  def self.default_processor
    :imagemagick
  end

  def self.processor
    case ENV['IMAGE_PROCESSOR']
    when 'imagemagick'
      Rails.logger.info('[ImageProcessor] Using ImageMagick as image processor')
      :imagemagick
    when 'graphicsmagick'
      Rails.logger.info('[ImageProcessor] Using GraphicsMagick as image processor')
      :graphicsmagick
    else
      Rails.logger.warn("[ImageProcessor] The environment variable IMAGE_PROCESSOR should be set to either 'imagemagick' or 'graphicsmagick'. It is currently set to: #{ENV['IMAGE_PROCESSOR']}. Defaulting to using #{default_processor}")
      default_processor
    end
  end

  def self.cli
    case processor
    when :graphicsmagick
      :graphicsmagick
    when :imagemagick
      :imagemagick
    end
  end

  def self.external_convert_command
    case processor
    when :graphicsmagick
      'gm convert'
    when :imagemagick
      'convert'
    end
  end

  def self.external_identify_command
    case processor
    when :graphicsmagick
      'gm identify'
    when :imagemagick
      'identify'
    end
  end
end
