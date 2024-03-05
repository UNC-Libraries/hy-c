# frozen_string_literal: true

module Tasks
  class DimensionsQueryService
    def initialize
      @dimensions_url = 'https://app.dimensions.ai/api'
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
        # Re-raise the error to propagate it up the call stack
        raise e
      end
    end

    def query_dimensions
      token = retrieve_token
      begin
        # Searching for publications related to UNC
        response = HTTParty.post(
            "#{@dimensions_url}/dsl",
            headers: { 'Content-Type' => 'application/json',
                       'Authorization' => "JWT #{token}" },
            body: { 'query' => 'search publications in raw_affiliations for "University of North Carolina, Chapel Hill" OR "UNC" return publications' }.to_json
        )
        # WIP: Remove later
        Rails.logger.info("Dimensions Response: #{response.parsed_response}")
        return response.parsed_response
      rescue HTTParty::Error, StandardError => e
        Rails.logger.error("HTTParty error during Dimensions API query: #{e.message}")
        raise e
      end
    end

  end
end
