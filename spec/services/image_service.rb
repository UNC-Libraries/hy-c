require 'rails_helper'

RSpec.describe ImageService do
  let(:service) { described_class }
  context 'using ImageMagick' do
    before do
      test_strategy = Flipflop::FeatureSet.current.test!
      test_strategy.switch!(:graphicsmagick, false)
    end

    it 'returns a symbol for imagemagick as the processor' do
      expect(service.processor).to eq(:imagemagick)
    end

    it 'returns the correct command for converting images' do
      expect(service.external_convert_command).to eq('convert')
    end

    it 'returns the correct command for identifying images' do
      expect(service.external_identify_command).to eq('identify')
    end
  end

  context 'using GraphicsMagick' do
    before do
      test_strategy = Flipflop::FeatureSet.current.test!
      test_strategy.switch!(:graphicsmagick, true)
    end

    it 'returns a symbol for graphicsmagick as the processor' do
      expect(service.processor).to eq(:graphicsmagick)
    end

    it 'returns the correct command for converting images' do
      expect(service.external_convert_command).to eq('gm convert')
    end

    it 'returns the correct command for identifying images' do
      expect(service.external_identify_command).to eq('gm identify')
    end
  end
end
