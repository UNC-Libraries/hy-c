module ImageService
  def self.processor
    if Flipflop.graphicsmagick?
      Rails.logger.info('[ImageProcessor] Using GraphicsMagick as image processor')
      :graphicsmagick
    else
      Rails.logger.info('[ImageProcessor] Using ImageMagick as image processor')
      :imagemagick
    end
  end

  def self.external_convert_command
    if Flipflop.graphicsmagick?
      Rails.logger.info('[ImageProcessor] Using GraphicsMagick for external_convert_command')
      'gm convert'
    else
      Rails.logger.info('[ImageProcessor] Using ImageMagick for external_convert_command')
      'convert'
    end
  end

  def self.external_identify_command
    if Flipflop.graphicsmagick?
      Rails.logger.info('[ImageProcessor] Using GraphicsMagick for external_identify_command')
      'gm identify'
    else
      Rails.logger.info('[ImageProcessor] Using ImageMagick for external_identify_command')
      'identify'
    end
  end
end
