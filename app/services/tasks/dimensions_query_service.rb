# frozen_string_literal: true

module Tasks
  class DimensionsQueryService
    def initialize
      @dimensions_url = 'https://app.dimensions.ai/api'
      @token = retrieve_token
    end

    def retrieve_token
      begin
        response = HTTParty.post(
          "#{@dimensions_url}/auth",
          headers: { 'Content-Type' => 'application/json' },
          body: { 'key' => "#{ENV['DIMENSIONS_API_KEY']}" }.to_json
        )

        if response.success?
          Rails.logger.info("Parsed Response: #{response.parsed_response}")
          return JSON.parse(response.parsed_response)['data']['token']
        else
          raise DimensionsTokenRetrievalError, "Failed to retrieve Dimensions API Token. Status code #{response.code}, response body: #{response.body}"
        end

      rescue HTTParty::Error, StandardError => e
        if e.is_a?(DimensionsTokenRetrievalError)
          Rails.logger.error("DimensionsTokenRetrievalError: #{e.message}")
        else
          Rails.logger.error("HTTParty error during Dimensions API token retrieval: #{e.message}")
        end
      end
    end

  end
end
