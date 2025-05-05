# frozen_string_literal: true
# [hyc-override] https://github.com/samvera/hydra-derivatives/blob/v3.8.0/lib/hydra/derivatives/processors/ffmpeg.rb
require 'redlock'

# [hyc-override] Add timeout error for ffmpeg
class FfmpegTimeoutError < Hydra::Derivatives::TimeoutError; end

Hydra::Derivatives::Processors::Ffmpeg.module_eval do
  # [hyc-override] Use Redlock to manage ffmpeg process lock
  LOCK_KEY = 'ffmpeg:video_conversion'
  LOCK_TIMEOUT = 200 * 60 * 1000 # Lock timeout should be longer than the job timeout
  JOB_TIMEOUT_SECONDS = 30 * 60 # 30 minutes
  LOCK_MANAGER = Redlock::Client.new([Redis.current])

  def self.encode(path, options, output_file)
    inopts = options[INPUT_OPTIONS] ||= '-y'
    outopts = options[OUTPUT_OPTIONS] ||= ''

    # [hyc-override] Use Redlock to limit the number of concurrent ffmpeg processes
    begin
      LOCK_MANAGER.lock(LOCK_KEY, LOCK_TIMEOUT) do |locked|
        if locked
          Rails.logger.debug("Acquired lock for ffmpeg #{path}")
          command = "#{Hydra::Derivatives.ffmpeg_path} #{inopts} -i #{Shellwords.escape(path)} #{outopts} #{output_file}"
          # [hyc-override] Use execute_with_timeout directly
          execute_with_timeout(timeout, command, {})
        else
          sleep(0.5)
          raise Redlock::LockError, "Failed to acquire lock for ffmpeg conversion of #{path}"
        end
      end
      Rails.logger.debug("Released ffmpeg lock for #{path}")
    rescue Redlock::LockError
      retry
    end
  end

  def self.execute_with_timeout(timeout, command, context)
    Timeout.timeout(timeout) do
      execute_without_timeout(command, context)
    end
  rescue Timeout::Error
    pid = context[:pid]
    if pid
      Rails.logger.warn("Terminating soffice process #{pid} after #{timeout} seconds")
      Process.kill('TERM', pid) # Attempt a graceful termination
      sleep 5 # Give it a few seconds to exit
      if system("ps -p #{pid}")
        Rails.logger.warn("Killing soffice process #{pid} after graceful termination failed")
        Process.kill('KILL', pid)
      end
      # Harvest the defunct process so it doesn't linger forever
      Process.wait(pid)
    end
    raise FfmpegTimeoutError, "Unable to execute command \"#{command}\"\nThe command took longer than #{timeout} seconds to execute"
  end
end
