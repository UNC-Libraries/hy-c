require 'open3'

# Job which causes registration of files to longleaf
class RegisterToLongleafJob < Hyrax::ApplicationJob
  queue_as Hyrax.config.ingest_queue_name

  def perform(checksum)
    if ENV['LONGLEAF_BASE_COMMAND'].blank?
      Rails.logger.error('LONGLEAF_BASE_COMMAND is not set, skipping registration of file to Longleaf.')
      return
    end

    # Calculate the path to the file in fedora, assuming modeshape behavior of hashing based on sha1
    binary_path = File.join(ENV['LONGLEAF_STORAGE_PATH'], checksum.scan(/.{2}/)[0..2].join('/'), checksum)

    register_cmd = "#{ENV["LONGLEAF_BASE_COMMAND"]} register -f #{binary_path} --checksums 'sha1:#{checksum}' --force"

    Rails.logger.debug("Registering with longleaf: #{register_cmd}")

    start = Time.now
    stdout, stderr, status = Open3.capture3(register_cmd)

    if status.success?
      Rails.logger.info("Successfully registered #{binary_path}")
    else
      Rails.logger.error("Failed to register #{binary_path} to Longleaf: #{stdout} #{stderr}")
      raise "#{stdout} #{stderr}"
    end

    Rails.logger.debug("Longleaf registration completed in #{Time.now - start}")
  end
end
