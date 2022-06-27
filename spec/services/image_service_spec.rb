require 'rails_helper'

RSpec.describe ImageService do
  let(:service) { described_class }
  context 'using GraphicsMagick' do
    around do |example|
      cached_image_processor = ENV['IMAGE_PROCESSOR']
      ENV['IMAGE_PROCESSOR'] = 'graphicsmagick'
      example.run
      ENV['IMAGE_PROCESSOR'] = cached_image_processor
    end

    it 'returns the correct processor' do
      expect(service.default_processor).to eq(:graphicsmagick)
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

    it 'defaults to graphicsmagick' do
      expect(service.default_processor).to eq(:graphicsmagick)
    end

    it 'defaults to graphicsmagick for everything' do
      expect(service.cli).to eq(:graphicsmagick)
      expect(service.external_convert_command).to eq('gm convert')
      expect(service.external_identify_command).to eq('gm identify')
    end
  end
end
