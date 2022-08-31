# frozen_string_literal: true
require 'open3'

# Job which causes deregistration of files to longleaf
class DeregisterLongleafJob < Hyrax::ApplicationJob
  queue_as Hyrax.config.ingest_queue_name

  def perform(file_set)
    repository_file = file_set.original_file

    if ENV['LONGLEAF_BASE_COMMAND'].blank?
      Rails.logger.error('LONGLEAF_BASE_COMMAND is not set, skipping deregistration of file to Longleaf.')
      return
    end

    checksum = repository_file.checksum.value
    # Calculate the path to the file in fedora, assuming modeshape behavior of hashing based on sha1
    binary_path = File.join(ENV['LONGLEAF_STORAGE_PATH'], checksum.scan(/.{2}/)[0..2].join('/'), checksum)

    deregister_cmd = "#{ENV["LONGLEAF_BASE_COMMAND"]} deregister -f #{binary_path}"

    Rails.logger.info("Deregistering with longleaf: #{deregister_cmd}")

    start = Time.now
    stdout, stderr, status = Open3.capture3(deregister_cmd)

    if status.success?
      Rails.logger.info("Successfully deregistered from Longleaf: #{binary_path}")
    else
      Rails.logger.error("Failed to deregister #{binary_path} to Longleaf: #{stdout} #{stderr}")
    end

    Rails.logger.info("Longleaf deregistration completed in #{Time.now - start}")
  end
end
