# frozen_string_literal: true
module ImageService
  def self.default_processor
    :graphicsmagick
  end

  def self.processor
    :graphicsmagick
  end

  def self.cli
    :graphicsmagick
  end

  def self.external_convert_command
    'gm convert'
  end

  def self.external_identify_command
    'gm identify'
  end
end
