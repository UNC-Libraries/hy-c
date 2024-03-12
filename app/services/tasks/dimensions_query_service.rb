# frozen_string_literal: true

module Tasks
  class DimensionsQueryService
    class DimensionsTokenRetrievalError < StandardError
    end
    class DimensionsPublicationQueryError < StandardError
    end
    def initialize
      @dimensions_url = 'https://app.dimensions.ai/api'
    end

    def query_dimensions(with_doi: true, page_size: 100)
      # Itializing a set in case the same publication shows up in subsequent queries
      all_publications = Set.new
      token = retrieve_token
      doi_clause = with_doi ? 'where doi is not empty' : 'where doi is empty'
      start = 0

      loop do
        begin
          query_string = <<~QUERY
                        search publications #{doi_clause} in raw_affiliations#{' '}
                        for """
                        "University of North Carolina, Chapel Hill" OR "UNC"
                        """#{'  '}
                        return publications[basics + extras]
                        limit #{page_size}
                        skip #{start}
                      QUERY
          # Searching for publications related to UNC
          response = HTTParty.post(
              "#{@dimensions_url}/dsl",
              headers: { 'Content-Type' => 'application/json',
                        'Authorization' => "JWT #{token}" },
              body: query_string,
              format: :json
          )
          if response.success?
            body = response.body
            parsed_body = JSON.parse(body)
            publications = deduplicate_publications(with_doi, parsed_body['publications'])
            all_publications.merge(publications)

            total_count = parsed_body['_stats']['total_count']
            start += page_size

            break if start >= total_count
          elsif response.code == 403
            # If the token has expired, retrieve a new token and try the query again
            # WIP: Not entirely sure if this is the correct way to handle this error, may cause an infinite loop
            Rails.logger.warn('Received 403 Forbidden error. Retrying after token refresh.')
            token = retrieve_token
            redo
          else
            raise DimensionsPublicationQueryError, "Failed to retrieve UNC affiliated articles from dimensions. Status code #{response.code}, response body: #{response.body}"
          end
        rescue HTTParty::Error, StandardError => e
          Rails.logger.error("HTTParty error during Dimensions API query: #{e.message}")
          raise e
        end
      end
      return all_publications.to_a
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
        Rails.logger.error("DimensionsTokenRetrievalError: #{e.message}")
        # Re-raise the error to propagate it up the call stack
        raise e
      end
    end

    def solr_query_builder(pub)
      pmcid_search = pub['pmcid'] ? "identifier_tesim:(\"PMCID: #{pub['pmcid']}\")" : nil
      pmid_search = pub['pmid'] ? "identifier_tesim:(\"PMID: #{pub['pmid']}\")" : nil
      title_search = pub['title'] ? "title_tesim:\"#{pub['title']}\"" : nil

      publication_data = [pmcid_search, pmid_search, title_search].compact
      query_string = publication_data.join(' OR ')
      return query_string
    end

    def deduplicate_publications(with_doi, publications)
      if with_doi
        # Removing publications with DOIs currently in Solr
        new_publications = publications.reject do |pub|
          doi_tesim = "https://doi.org/#{pub['doi']}"
          result = Hyrax::SolrService.get("doi_tesim:\"#{doi_tesim}\"")
          !result['response']['docs'].empty?
        end
        return new_publications
      else
        # Deduplicate publications by pmcid, pmid and title
        new_publications = publications.reject do |pub|
          query_string = solr_query_builder(pub)
          result = Hyrax::SolrService.get(query_string)
          # Mark publications for review if they are not found in Solr and do not have a pmcid or pmid
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
