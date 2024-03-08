# frozen_string_literal: true

module Tasks
  class DimensionsTokenRetrievalError < StandardError
  end
  class DimensionsPublicationQueryError < StandardError
  end

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
          return response.parsed_response['token']
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

    # def deduplicate_publications(with_doi,publications)


    def query_dimensions(with_doi: true)
      token = retrieve_token
      begin
        doi_clause = with_doi ? 'where doi is not empty' : 'where doi is empty'
        query_string = <<~QUERY
                      search publications #{doi_clause} in raw_affiliations#{' '}
                      for """
                      "University of North Carolina, Chapel Hill" OR "UNC"
                      """#{'  '}
                      return publications[basics + extras]
                    QUERY
        # Searching for publications related to UNC
        response = HTTParty.post(
            "#{@dimensions_url}/dsl",
            headers: { 'Content-Type' => 'application/json',
                       'Authorization' => "JWT #{token}" },
            body: query_string
        )
        if response.success?
          publications = response.parsed_response['publications']
          # WIP: Deduplicate publications
          return publications
        else
          raise DimensionsPublicationQueryError, "Failed to retrieve UNC affiliated articles from dimensions. Status code #{response.code}, response body: #{response.body}"
        end
      rescue HTTParty::Error, StandardError => e
        Rails.logger.error("HTTParty error during Dimensions API query: #{e.message}")
        raise e
      end
    end

  end
end
