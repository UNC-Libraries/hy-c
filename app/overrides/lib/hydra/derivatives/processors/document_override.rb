# frozen_string_literal: true
# [hyc-override] https://github.com/samvera/hydra-derivatives/blob/v3.8.0/lib/hydra/derivatives/processors/document.rb
class SofficeTimeoutError < StandardError; end

Hydra::Derivatives::Processors::Document.class_eval do
  LOCK_KEY = "soffice:document_conversion"
  LOCK_TIMEOUT = 6 * 60 * 1000
  JOB_TIMEOUT_SECONDS = 30
  LOCK_MANAGER = Redlock::Client.new([ENV['REDIS_URL']])

  # [hyc-override] Trigger kill if soffice process takes too long, and throw a non-retry error if that happens
  def self.encode(path, format, outdir, timeout = JOB_TIMEOUT_SECONDS)
    command = "#{Hydra::Derivatives.libreoffice_path} --invisible --headless --convert-to #{format} --outdir #{outdir} #{Shellwords.escape(path)}"
    pid = nil
    begin
      Timeout.timeout(timeout) do
        # Use Process.spawn to track the process and capture the pid
        pid = Process.spawn(command)
        Process.wait(pid) # Wait for the process to complete
      end
    rescue Timeout::Error
      # If it times out, terminate the process
      if pid
        Process.kill('TERM', pid) # Attempt a graceful termination
        sleep 5 # Give it a few seconds to exit
        Process.kill('KILL', pid) if system("ps -p #{pid}") # Force kill if still running
      end
      # Raise a custom error to prevent Sidekiq from retrying
      raise SofficeTimeoutError, "soffice process timed out after #{timeout} seconds"
    end
  end

  # TODO: soffice can only run one command at a time. Right now we manage this by only running one
  # background job at a time; however, if we want to up concurrency we'll need to deal with this

  # Converts the document to the format specified in the directives hash.
  # TODO: file_suffix and options are passed from ShellBasedProcessor.process but are not needed.
  #       A refactor could simplify this.
  def encode_file(_file_suffix, _options = {})
    LOCK_MANAGER.lock(LOCK_KEY, LOCK_TIMEOUT) do |locked|
      if locked
        convert_to_format
      else
        raise "Could not acquire lock for document conversion of #{source_path}"
      end
    end
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
