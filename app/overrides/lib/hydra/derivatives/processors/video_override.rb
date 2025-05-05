# frozen_string_literal: true
module Hydra::Derivatives::Processors
  module Video
    class Processor < Hydra::Derivatives::Processors::Processor
      # Original class includes Ffmpeg module

      # Override the encode class method to add locking
      class << self
        alias_method :original_encode, :encode

        def encode(path, options, output_file)
          FfmpegLocking.with_ffmpeg_lock do
            Rails.logger.error("Video encode acquired lock with path: #{path}, options: #{options}, output_file: #{output_file}")
            original_encode(path, options, output_file)
          end
        end
      end
    end
  end
end
