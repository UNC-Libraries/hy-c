# frozen_string_literal: true
module Hydra::Derivatives::Processors
  class Audio < Processor
    # Override the encode class method to add locking
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
