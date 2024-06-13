# frozen_string_literal: true

module Tasks
  class DimensionsQueryService
    class DimensionsTokenRetrievalError < StandardError
    end
    class DimensionsPublicationQueryError < StandardError
    end
    DIMENSIONS_URL = 'https://app.dimensions.ai/api'
    EARLIEST_DATE = '1970-01-01'
    MAX_RETRIES = 0

    def query_dimensions(with_doi: true, page_size: 100, date_inserted: nil)
      date_inserted ||= EARLIEST_DATE
      # Initialized as a set to avoid retrieving duplicate publications from Dimensions if the page size exceeds the number of publications on the last page.
      all_publications = Set.new
      token = retrieve_token
      search_clauses = generate_search_clauses(with_doi, date_inserted)
      return_fields = generate_return_fields

      # WIP: Cursor should be initialized to 0 and cursor_limit removed
      cursor = 2000
      retries = 0
      cursor_limit = 2020
        # Flag to track if retry has been attempted after token refresh
      retry_attempted = false
      loop do
        begin
          query_string = generate_query_string(search_clauses, return_fields, page_size, cursor)
          Rails.logger.info("Querying Dimensions API with query: #{query_string}")
          response = post_query(query_string, token)
          if response.success?
            # Merge the new publications with the existing set
            all_publications.merge(process_response(response, with_doi))
            total_count = response['_stats']['total_count']
            cursor += page_size
            # End the loop if the cursor exceeds the total count
            # WIP: Limited Sample for testing
            # break if cursor >= total_count
            break if cursor >= total_count || cursor >= cursor_limit
          elsif response.code == 403
            unless retry_attempted
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
          handle_query_error(e, retries)
          retries += 1
          retry if retries <= MAX_RETRIES
          raise e
        end
      end
      # end
      return all_publications.to_a
    end

    def handle_query_error(error, retries)
      Rails.logger.error("HTTParty error during Dimensions API query: #{error.message}")
      if retries <= MAX_RETRIES
        Rails.logger.warn("Retrying query after #{2**retries} seconds.")
        sleep(2**retries) # Using base 2 for exponential backoff
      end
    end

    # Extra headers to avoid 400 bad request error
    def post_query(query_string, token)
      content_length = query_string.to_s.bytesize
      HTTParty.post(
        "#{DIMENSIONS_URL}/dsl",
        headers: {
          'Content-Type' => 'application/json',
          'Authorization' => "JWT #{token}",
          'Host' => URI(DIMENSIONS_URL).host,
          'Content-Length' => content_length.to_s,
          'Connection' => 'keep-alive',
          'Accept-Encoding' => 'gzip, deflate, br'
        },
        body: query_string,
        format: :json,
        timeout: 100
      )
    end

    def process_response(response, with_doi)
      parsed_body = JSON.parse(response.body)
      publications = deduplicate_publications(with_doi, parsed_body['publications'])
      Rails.logger.info("Dimensions API returned #{parsed_body['publications'].size} publications.")
      Rails.logger.info("Unique Publications after Deduplicating: #{publications.size}.")
      publications
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
      title_quote_escaped = pub['title'] ? pub['title'].gsub(/"/, '\\"') : nil
      title_search = pub['title'] ? "title_tesim:\"#{title_quote_escaped}\"" : nil
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
          result = Hyrax::SolrService.get("doi_tesim:\"#{doi_tesim}\" OR identifier_tesim:\"#{pub['doi']}\"")
          !result['response']['docs'].empty?
        end

        # Log the DOI and title of each publication that was removed
        removed_publications = publications - new_publications
        removed_publications.each do |pub|
          Rails.logger.info("Removed duplicate publication with DOI: #{pub['doi']} and title: #{pub['title']}")
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

    # WIP: Retrieve publications without pmcid and pmid for testing, and with linkout
    def generate_search_clauses(with_doi, date_inserted)
      [with_doi ? 'where doi is not empty' : 'where doi is empty', 'type = "article"', "date_inserted >= \"#{date_inserted}\"", "pmcid is empty", "pmid is empty", "linkout is not empty"].join(' and ')
    end

    def generate_return_fields
      ['basics', 'extras', 'abstract', 'issn', 'publisher', 'journal_title_raw', 'linkout'].join(' + ')
    end 

    # Query with paramaters to retrieve publications related to UNC
    def generate_query_string(search_clauses, return_fields, page_size, cursor)
      <<~QUERY
        search publications #{search_clauses} in raw_affiliations
        for """
        "University of North Carolina, Chapel Hill" OR "UNC"
        """
        return publications[#{return_fields}]
        limit #{page_size}
        skip #{cursor}
      QUERY
    end
end
end
