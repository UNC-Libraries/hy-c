# frozen_string_literal: true
require 'rails_helper'
require Rails.root.join('app/overrides/lib/hydra/derivatives/processors/ffmpeg_locking.rb')

describe Hydra::Derivatives::Processors::Video::Processor do
  describe '.encode' do
    let(:path) { '/path/to/video.mp4' }
    let(:options) { { resolution: '320x240' } }
    let(:output_file) { 'output.mp4' }

    before do
      # Mock the original encode method
      allow(described_class).to receive(:original_encode)

      # Mock FfmpegLocking
      allow(Hydra::Derivatives::Processors::FfmpegLocking).to receive(:with_ffmpeg_lock).and_yield

      # Mock Rails.logger
      allow(Rails.logger).to receive(:info)
    end

    after do
      # Restore original behavior after tests if needed
      # This might not be necessary depending on your test setup
    end

    it 'wraps the original encode method with ffmpeg locking' do
      # Expect the with_ffmpeg_lock method to be called
      expect(Hydra::Derivatives::Processors::FfmpegLocking).to receive(:with_ffmpeg_lock).once
      expect(described_class).to receive(:original_encode).with(path, options, output_file)
      expect(Rails.logger).to receive(:info).with("Video encode acquired lock with path: #{path}, options: #{options}, output_file: #{output_file}")

      # Call the encode method
      described_class.encode(path, options, output_file)
    end
  end
end
