# frozen_string_literal: true

# Job which causes deregistration of files to longleaf
class DeregisterLongleafJob < Hyrax::ApplicationJob
  queue_as Hyrax.config.ingest_queue_name

  def perform(checksum)
    base_path = ENV['LONGLEAF_API_HOST_PATH']
    # Calculate the path to the file in fedora, assuming modeshape behavior of hashing based on sha1
    path_to_file = File.join(ENV['LONGLEAF_STORAGE_PATH'], checksum.scan(/.{2}/)[0..2].join('/'), checksum)

    start = Time.now
    Rails.logger.debug("Deregistering with longleaf: #{path_to_file}")

    response = HTTParty.delete(
      "#{base_path}/api/deregister",
      headers: { "Content-Type": 'application/json' },
      body:  { file: path_to_file }.to_json,
      format: :json
    )

    if response.code == 200
      body = JSON.parse(response.body)
      success = body['success']
      failure = body['failure']
      unless success.empty?
        Rails.logger.info("Successfully deregistered #{path_to_file}")
      end
      unless failure.empty?
        error_message = "Failed to deregister #{path_to_file} from Longleaf. Status code #{response.code}, response body: #{response.body}"
        Rails.logger.error(error_message)
        raise error_message
      end
    else
      error_message = "Longleaf deregister API returned status #{response.code} for #{path_to_file}"
      Rails.logger.error(error_message)
      raise error_message
    end

    Rails.logger.info("Longleaf deregistration completed in #{Time.now - start}")
  end
end
