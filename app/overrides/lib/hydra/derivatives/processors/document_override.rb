# frozen_string_literal: true
# [hyc-override] https://github.com/samvera/hydra-derivatives/blob/v3.8.0/lib/hydra/derivatives/processors/document.rb
require 'redlock'

class SofficeTimeoutError < Hydra::Derivatives::TimeoutError; end

Hydra::Derivatives::Processors::Document.class_eval do
  # [hyc-override] Use Redlock to manage soffice process lock
  LOCK_KEY = 'soffice:document_conversion'
  LOCK_TIMEOUT = 6 * 60 * 1000 # Lock timeout should be longer than the job timeout
  JOB_TIMEOUT_SECONDS = 5 * 60
  LOCK_MANAGER = Redlock::Client.new([Redis.current])

  # [hyc-override] Adding in a graceful termination before hard kill, reap the process after kill
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
    raise SofficeTimeoutError, "Unable to execute command \"#{command}\"\nThe command took longer than #{timeout} seconds to execute"
  end

  def self.encode(path, format, outdir, timeout = JOB_TIMEOUT_SECONDS)
    # [hyc-override] Use Redlock to manage soffice process lock, since only one soffice process can run at a time
    begin
      LOCK_MANAGER.lock(LOCK_KEY, LOCK_TIMEOUT) do |locked|
        if locked
          Rails.logger.debug("Acquired lock for document conversion of #{path}")
          command = "#{Hydra::Derivatives.libreoffice_path} --invisible --headless --convert-to #{format} --outdir #{outdir} #{Shellwords.escape(path)}"
          # [hyc-override] Use execute_with_timeout directly
          execute_with_timeout(timeout, command, {})
        else
          sleep(0.5)
          raise Redlock::LockError, "Failed to acquire lock for document conversion of #{path}"
        end
      end
      Rails.logger.debug("Released soffice lock for #{path}")
    rescue Redlock::LockError
      retry
    end
  end

  # Converts the document to the format specified in the directives hash.
  # TODO: file_suffix and options are passed from ShellBasedProcessor.process but are not needed.
  #       A refactor could simplify this.
  def encode_file(_file_suffix, _options = {})
    convert_to_format
  ensure
    FileUtils.rm_f(converted_file)
    # [hyc-override] clean up the parent temp dir
    FileUtils.rmdir(File.dirname(converted_file))
  end

  private
  def convert_to(format)
    # [hyc-override] create temp subdir for output to avoid repeat filename conflicts
    Rails.logger.debug("Converting document to #{format} from source path: #{source_path} to destination file: #{directives[:url]}")

    temp_dir = File.join(Hydra::Derivatives.temp_file_base, Time.now.nsec.to_s)
    FileUtils.mkdir(temp_dir)
    Rails.logger.debug("Temp directory created for derivatives: #{temp_dir}")

    self.class.encode(source_path, format, temp_dir)

    File.join(temp_dir, [File.basename(source_path, '.*'), format].join('.'))
  end
end
