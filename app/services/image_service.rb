module ImageService
  def self.processor
    if Flipflop.graphicsmagick?
      :graphicsmagick
    else
      :imagemagick
    end
  end

  def self.external_convert_command
    if Flipflop.graphicsmagick?
      'gm convert'
    else
      'convert'
    end
  end

  def self.external_identify_command
    if Flipflop.graphicsmagick?
      'gm identify'
    else
      'identify'
    end
  end
end
