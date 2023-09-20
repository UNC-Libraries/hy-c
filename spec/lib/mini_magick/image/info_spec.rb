# frozen_string_literal: true
# [hyc-override] https://github.com/minimagick/minimagick/blob/v4.12.0/lib/mini_magick/image/info.rb
require 'rails_helper'

RSpec.describe MiniMagick::Image::Info do
  subject { MiniMagick::Image::Info.new('path/to/file') }
  before do
    allow(File).to receive(:size).with('path/to/file').and_return(12345)
  end

  describe '#cheap_info' do
    context 'with error message and no info' do
      before do
        allow(subject).to receive(:raw).and_return(
          %q{    **** Error: Form stream has unbalanced q/Q operators (too many qs)
          Output may be incorrect.}
        )
      end

      it 'throws error and logs error message' do
        expect(Rails.logger).to receive(:warn).with('Error logged for image:     **** Error: Form stream has unbalanced q/Q operators (too many qs)')
        expect(Rails.logger).to receive(:warn).with('Error logged for image:           Output may be incorrect.')
        expect { subject.cheap_info('width') }.to raise_error
      end
    end

    context 'with warn message' do
      before do
        allow(subject).to receive(:raw).and_return(
          "    **** Warning: This image is bad.\nJPEG 1200 1000 12345B"
        )
      end

      it 'returns the data and logs message as info' do
        expect(Rails.logger).to receive(:info).with('Warning logged for image:     **** Warning: This image is bad.')
        expect(subject.cheap_info('width')).to eq 1200
      end
    end

    context 'with just the file info' do
      before do
        allow(subject).to receive(:raw).and_return('JPEG 1200 1000 12345B')
      end

      it 'returns the data and no logger' do
        expect(Rails.logger).to_not receive(:warn)
        expect(subject.cheap_info('width')).to eq 1200
      end
    end
  end
end
