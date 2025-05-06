# frozen_string_literal: true
# [hyc-override] https://github.com/samvera/hydra-derivatives/blob/v3.8.0/lib/hydra/derivatives/processors/audio.rb
module Hydra::Derivatives::Processors
  class Audio < Processor
    # [hyc-override] wrap original encode method to add ffmpeg locking
    class << self
      alias_method :original_encode, :encode

      def encode(path, options, output_file)
        FfmpegLocking.with_ffmpeg_lock do
          Rails.logger.info("Audio encode acquired lock with path: #{path}, options: #{options}, output_file: #{output_file}")
          original_encode(path, options, output_file)
        end
      end
    end
  end
end
