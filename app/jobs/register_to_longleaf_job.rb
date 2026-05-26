# frozen_string_literal: true

# Job which causes registration of files to longleaf
class RegisterToLongleafJob < Hyrax::ApplicationJob
  queue_as Hyrax.config.ingest_queue_name

  def perform(checksum)
    base_path = ENV['LONGLEAF_API_HOST_PATH']
    if base_path.blank?
      Rails.logger.error('LONGLEAF_API_HOST_PATH is not set, skipping registration of file to Longleaf.')
      return
    end
    # Calculate the path to the file in fedora, assuming modeshape behavior of hashing based on sha1
    path_to_file = File.join(ENV['LONGLEAF_STORAGE_PATH'], checksum.scan(/.{2}/)[0..2].join('/'), checksum)

    start = Time.now
    Rails.logger.debug("Registering with longleaf: #{path_to_file}")

    response = HTTParty.post(
      "#{base_path}/api/register",
      headers: { "Content-Type": 'application/json' },
      body:  {
        file: path_to_file,
        checksum: checksum,
        force: true
      }.to_json,
      format: :json
    )

    if response.code == 200
      body = JSON.parse(response.body)
      success = body['success']
      failure = body['failure']
      unless success.empty?
        Rails.logger.info("Successfully registered #{path_to_file}")
      end
      unless failure.empty?
        error_message = "Failed to register #{path_to_file} to Longleaf. Status code #{response.code}, response body: #{response.body}"
        Rails.logger.error(error_message)
        raise error_message
      end
    else
      error_message = "Longleaf register API returned status #{response.code} for #{path_to_file}"
      Rails.logger.error(error_message)
      raise error_message
    end

    Rails.logger.debug("Longleaf registration completed in #{Time.now - start}")
  end
end
