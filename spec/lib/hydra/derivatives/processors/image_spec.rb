# frozen_string_literal: true
require 'rails_helper'
require Rails.root.join('spec/support/image_source_data.rb')

RSpec.describe Hydra::Derivatives::Processors::Image do
  subject { described_class.new(file_name, directives) }

  let(:file_name) { 'file_name' }

  describe '#process' do
    let(:directives) { { size: '100x100>', format: 'png', url: 'file:/tmp/12/34/56/7-thumbnail.jpeg' } }

    context 'when a timeout is set' do
      before do
        subject.timeout = 0.1
        allow(subject).to receive(:create_resized_image) { sleep 0.2 }
      end
      it 'raises a timeout exception' do
        expect { subject.process }.to raise_error Hydra::Derivatives::TimeoutError
      end
    end

    context 'when not set' do
      before { subject.timeout = nil }
      it 'processes without a timeout' do
        expect(subject).to receive(:process_with_timeout).never
        expect(subject).to receive(:create_resized_image).once
        subject.process
      end
    end

    context 'when running the complete command' do
      let(:file_name) { File.join(fixture_path, 'derivatives', 'test.tif') }

      it 'calls the GraphicsMagick version of create_resized_image' do
        expect(subject).to receive(:create_resized_image_with_graphicsmagick)
        subject.process
      end

      it 'converts the image' do
        expect(Hyrax::PersistDerivatives).to receive(:call).with(kind_of(StringIO), directives)
        subject.process
      end

      it 'gets the source data' do
        expect(subject).to receive(:source_data).and_return(IMAGE_SOURCE_DATA)
        subject.process
      end
    end
  end

  context 'using GraphicsMagick' do
    let(:directives) { { size: '100x100>', format: 'png', url: 'file:/tmp/12/34/56/7-thumbnail.jpeg' } }
    let(:file_name) { File.join(fixture_path, 'derivatives', 'test.tif') }

    before do
      allow(MiniMagick).to receive(:cli).and_return(:graphicsmagick)
    end

    around do |example|
      cached_image_processor = ENV['IMAGE_PROCESSOR']
      ENV['IMAGE_PROCESSOR'] = 'graphicsmagick'
      example.run
      ENV['IMAGE_PROCESSOR'] = cached_image_processor
    end

    it 'calls the GraphicsMagick version of create_resized_image' do
      expect(subject).to receive(:create_resized_image_with_graphicsmagick)
      subject.process
    end

    context 'when running the complete command' do
      let(:file_name) { File.join(fixture_path, 'derivatives', 'test.tif') }

      it 'converts the image' do
        expect(Hyrax::PersistDerivatives).to receive(:call).with(kind_of(StringIO), directives)
        subject.process
      end

      it 'gets the source data' do
        expect(subject).to receive(:source_data).and_return(IMAGE_SOURCE_DATA)
        subject.process
      end
    end
  end
end
