# frozen_string_literal: true

module Hydra::Derivatives::Processors
  module FfmpegLocking
    # Lock resource name for ffmpeg processes
    FFMPEG_LOCK_KEY = 'ffmpeg_process_lock'

    DEFAULT_LOCK_EXPIRY = 60 * 30 * 1000 # 30 minutes

    def self.lock_manager
      @lock_manager ||= Redlock::Client.new([Redis.current])
    end

    # Execute with a distributed lock to prevent too many ffmpeg processes
    # from running simultaneously
    def self.with_ffmpeg_lock
      begin
        lock_manager.lock(FFMPEG_LOCK_KEY, DEFAULT_LOCK_EXPIRY) do |locked|
          if locked
            yield
          else
            sleep(0.5)
            raise Redlock::LockError, 'Failed to acquire lock for ffmpeg conversion'
          end
        end
      rescue Redlock::LockError
        Rails.logger.debug('Failed to acquire ffmpeg lock')
        retry
      end
    end
  end
end
