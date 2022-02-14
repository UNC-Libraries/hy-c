require 'rails_helper'

RSpec.describe ImageService do
  let(:service) { described_class }
  context 'using ImageMagick' do
    around do |example|
      cached_image_processor = ENV['IMAGE_PROCESSOR']
      ENV['IMAGE_PROCESSOR'] = 'imagemagick'
      example.run
      ENV['IMAGE_PROCESSOR'] = cached_image_processor
    end

    it 'returns the correct processor' do
      expect(service.processor).to eq(:imagemagick)
    end

    it 'returns a symbol for imagemagick as the cli' do
      expect(service.cli).to eq(:imagemagick)
    end

    it 'returns the correct command for converting images' do
      expect(service.external_convert_command).to eq('convert')
    end

    it 'returns the correct command for identifying images' do
      expect(service.external_identify_command).to eq('identify')
    end
  end

  context 'using GraphicsMagick' do
    around do |example|
      cached_image_processor = ENV['IMAGE_PROCESSOR']
      ENV['IMAGE_PROCESSOR'] = 'graphicsmagick'
      example.run
      ENV['IMAGE_PROCESSOR'] = cached_image_processor
    end

    it 'returns the correct processor' do
      expect(service.processor).to eq(:graphicsmagick)
    end

    it 'returns a symbol for graphicsmagick as the cli' do
      expect(service.cli).to eq(:graphicsmagick)
    end

    it 'returns the correct command for converting images' do
      expect(service.external_convert_command).to eq('gm convert')
    end

    it 'returns the correct command for identifying images' do
      expect(service.external_identify_command).to eq('gm identify')
    end
  end

  context 'without the environment variable set' do
    around do |example|
      cached_image_processor = ENV['IMAGE_PROCESSOR']
      ENV['IMAGE_PROCESSOR'] = ''
      example.run
      ENV['IMAGE_PROCESSOR'] = cached_image_processor
    end

    # TODO: Once we're using GraphicsMagick across all environments, we should switch the default to GraphicsMagick
    it 'defaults to imagemagick' do
      expect(service.processor).to eq(:imagemagick)
      expect(service.default_processor).to eq(:imagemagick)
    end

    # TODO: Once we're using GraphicsMagick across all environments, we should switch the default to GraphicsMagick
    it 'defaults to imagemagick for everything' do
      expect(service.cli).to eq(:imagemagick)
      expect(service.external_convert_command).to eq('convert')
      expect(service.external_identify_command).to eq('identify')
    end
  end
end
