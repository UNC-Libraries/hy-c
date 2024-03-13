# frozen_string_literal: true

module Tasks
  class DimensionsQueryService
    class DimensionsTokenRetrievalError < StandardError
    end
    class DimensionsPublicationQueryError < StandardError
    end
    DIMENSIONS_URL = 'https://app.dimensions.ai/api'

    def query_dimensions(with_doi: true, page_size: 100)
      # Initialized as a set to avoid retrieving duplicate publications from Dimensions if the page size exceeds the number of publications on the last page.
      all_publications = Set.new
      token = retrieve_token
      doi_clause = with_doi ? 'where doi is not empty' : 'where doi is empty'
      cursor = 0
      # Flag to track if retry has been attempted after token refresh
      retry_attempted = false

      loop do
        begin
          # Query with paramaters to retrieve publications related to UNC
          query_string = <<~QUERY
                        search publications #{doi_clause} in raw_affiliations#{' '}
                        for """
                        "University of North Carolina, Chapel Hill" OR "UNC"
                        """#{'  '}
                        return publications[basics + extras]
                        limit #{page_size}
                        skip #{cursor}
                      QUERY
          response = HTTParty.post(
              "#{DIMENSIONS_URL}/dsl",
              headers: { 'Content-Type' => 'application/json',
                        'Authorization' => "JWT #{token}" },
              body: query_string,
              format: :json
          )
          if response.success?
            # Merge the new publications with the existing set
            parsed_body = JSON.parse(response.body)
            publications = deduplicate_publications(with_doi, parsed_body['publications'])
            all_publications.merge(publications)

            # End the loop if the cursor exceeds the total count
            total_count = parsed_body['_stats']['total_count']
            cursor += page_size

            break if cursor >= total_count
          elsif response.code == 403
            if !retry_attempted
              # If the token has expired, retrieve a new token and try the query again
              Rails.logger.warn('Received 403 Forbidden error. Retrying after token refresh.')
              token = retrieve_token
              retry_attempted = true
              redo
            else
              # If the token has expired and retry has already been attempted, raise a specific error
              raise DimensionsPublicationQueryError, 'Retry attempted after token refresh failed with 403 Forbidden error'
            end
          else
            raise DimensionsPublicationQueryError, "Failed to retrieve UNC affiliated articles from dimensions. Status code #{response.code}, response body: #{response.body}"
          end
        rescue HTTParty::Error, StandardError => e
          Rails.logger.error("HTTParty error during Dimensions API query: #{e.message}")
          # Re-raise the error to propagate it up the call stack
          raise e
        end
      end
      return all_publications.to_a
    end

    def retrieve_token
      begin
        response = HTTParty.post(
          "#{DIMENSIONS_URL}/auth",
          headers: { 'Content-Type' => 'application/json' },
          body: { 'key' => "#{ENV['DIMENSIONS_API_KEY']}" }.to_json
        )
        if response.success?
          return response.parsed_response['token']
        else
          raise DimensionsTokenRetrievalError, "Failed to retrieve Dimensions API Token. Status code #{response.code}, response body: #{response.body}"
        end
      rescue HTTParty::Error, StandardError => e
        Rails.logger.error("DimensionsTokenRetrievalError: #{e.message}")
        # Re-raise the error to propagate it up the call stack
        raise e
      end
    end

    def solr_query_builder(pub)
      # Build a query string to search Solr for a publication based on pmcid, pmid, or title
      pmcid_search = pub['pmcid'] ? "identifier_tesim:(\"PMCID: #{pub['pmcid']}\")" : nil
      pmid_search = pub['pmid'] ? "identifier_tesim:(\"PMID: #{pub['pmid']}\")" : nil
      title_search = pub['title'] ? "title_tesim:\"#{pub['title']}\"" : nil

      # Combine the search terms into a single query string excluding nil values
      publication_data = [pmcid_search, pmid_search, title_search].compact
      query_string = publication_data.join(' OR ')
      return query_string
    end

    def deduplicate_publications(with_doi, publications)
      if with_doi
        # Removing publications that have a matching DOI in Solr
        new_publications = publications.reject do |pub|
          doi_tesim = "https://doi.org/#{pub['doi']}"
          result = Hyrax::SolrService.get("doi_tesim:\"#{doi_tesim}\"")
          !result['response']['docs'].empty?
        end
        return new_publications
      else
        # Removing publications that have a matching PMID, PMCID, or title in Solr
        new_publications = publications.reject do |pub|
          query_string = solr_query_builder(pub)
          result = Hyrax::SolrService.get(query_string)
          # Mark a publication for review if it has a unique title and no unique identifiers
          if result['response']['docs'].empty? and pub['pmcid'].nil? and pub['pmid'].nil?
            pub['marked_for_review'] = true
          end
          !result['response']['docs'].empty?
        end
        return new_publications
      end

    end
end
end
