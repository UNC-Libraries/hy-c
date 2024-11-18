# frozen_string_literal: true
# [hyc-override] https://github.com/samvera/hydra-derivatives/blob/v3.8.0/lib/hydra/derivatives/processors/document.rb
require 'redlock'

class SofficeTimeoutError < Hydra::Derivatives::TimeoutError; end

Hydra::Derivatives::Processors::Document.class_eval do
  # [hyc-override] Use Redlock to manage soffice process lock
  LOCK_KEY = 'soffice:document_conversion'
  LOCK_TIMEOUT = 6 * 60 * 1000
  JOB_TIMEOUT_SECONDS = 30
  LOCK_MANAGER = Redlock::Client.new([Redis.current])

  # [hyc-override] Adding in a graceful termination before hard kill, use spawn for process group
  def self.execute_with_timeout(timeout, command, context)
    stdout, stderr = "", ""
    pid = nil
    status = nil

    Timeout.timeout(timeout) do
      # Create pipes for stdout and stderr
      stdout_r, stdout_w = IO.pipe
      stderr_r, stderr_w = IO.pipe

      # Use Process.spawn to start the command with process group
      pid = Process.spawn(command, :pgroup => true, :out => stdout_w, :err => stderr_w)

      # Close unused ends in parent process
      stdout_w.close
      stderr_w.close

      # Read the output in separate threads to avoid deadlocks
      stdout_thread = Thread.new { stdout = stdout_r.read }
      stderr_thread = Thread.new { stderr = stderr_r.read }

      # Wait for the process to complete
      _, status = Process.wait2(pid)

      # Ensure threads finish reading
      stdout_thread.join
      stderr_thread.join
    end
    raise "Unable to execute command \"#{command}\". Exit code: #{status}\nError message: #{stderr}" unless status == 0
  rescue Timeout::Error
     # If it times out, terminate the process
     if pid
      Process.kill('TERM', pid) # Attempt a graceful termination
      sleep 5 # Give it a few seconds to exit
      Process.kill('KILL', pid) if system("ps -p #{pid}") # Force kill if still running
    end
    # Raise a custom error to prevent Sidekiq from retrying
    raise SofficeTimeoutError, "soffice process timed out after #{timeout} seconds"
  rescue EOFError
    Rails.logger.debug "Caught an eof error in ShellBasedProcessor"
  end

  # [hyc-override] Trigger kill if soffice process takes too long, and throw a non-retry error if that happens
  def self.encode(path, format, outdir, timeout = JOB_TIMEOUT_SECONDS)
    Rails.logger.error("Converting document to #{format} from source path: #{path} to destination file: #{outdir}")
    Rails.logger.error("Encode backtrace #{Thread.current.backtrace.join("\n")}")
    command = "#{Hydra::Derivatives.libreoffice_path} --invisible --headless --convert-to #{format} --outdir #{outdir} #{Shellwords.escape(path)}"
    execute_with_timeout(timeout, command, {})
  end

  # Converts the document to the format specified in the directives hash.
  # TODO: file_suffix and options are passed from ShellBasedProcessor.process but are not needed.
  #       A refactor could simplify this.
  def encode_file(_file_suffix, _options = {})
    # [hyc-override] Use Redlock to manage soffice process lock, since only one soffice process can run at a time
    LOCK_MANAGER.lock(LOCK_KEY, LOCK_TIMEOUT) do |locked|
      if locked
        Rails.logger.error("Acquired lock for document conversion of #{source_path}")
        convert_to_format
      else
        raise "Could not acquire lock for document conversion of #{source_path}"
      end
    end
    Rails.logger.error("Released lock for #{source_path}")
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
