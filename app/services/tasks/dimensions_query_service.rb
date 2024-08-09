# frozen_string_literal: true

module Tasks
  class DimensionsQueryService
    class DimensionsTokenRetrievalError < StandardError
    end
    class DimensionsPublicationQueryError < StandardError
    end
    DIMENSIONS_URL = 'https://app.dimensions.ai/api'
    MAX_RETRIES = 5

    attr_accessor :dimensions_total_count

    def initialize
      @dimensions_total_count = 0
    end

    def query_dimensions(options = {})
      start_date = options[:start_date]
      end_date = options[:end_date]
      page_size = options[:page_size] || 100

      unless end_date and start_date
        raise ArgumentError, 'Both start_date and end_date must be provided.'
      end

      # Initialized as a set to avoid retrieving duplicate publications from Dimensions if the page size exceeds the number of publications on the last page.
      all_publications = Set.new
      token = retrieve_token

      cursor = 0
      # Wrapped value for tracking retries inside of an array to allow for pass by reference in the query_needs_retry? method
      retries = [0]
      query_count = 0
      # Flag to track if retry has been attempted after token refresh
      retry_attempted = false
      loop do
        begin
          query_string = generate_query_string(start_date, end_date, page_size, cursor)
          Rails.logger.info("Sending query ##{query_count += 1} to Dimensions API: #{query_string}")
          response = post_query(query_string, token)
          if response.success?
            # Merge the new publications with the existing set
            all_publications.merge(process_response(response))
            # total_count = response['_stats']['total_count']
            self.dimensions_total_count = response.parsed_response['_stats']['total_count']
            cursor += page_size
            # End the loop if the cursor exceeds the total count
            # WIP: Break if cursor is greater than or equal to 100 for testing purposes
            # break if cursor >= total_count || cursor >= 100
            break if cursor >= self.dimensions_total_count
            # Reset the retry count if the query is successful
            retries[0] = 0
          elsif response.code == 403
            unless retry_attempted
              # If the token has expired, retrieve a new token and try the query again
              Rails.logger.warn('Received 403 Forbidden error. Retrying after token refresh.')
              token = retrieve_token
              retry_attempted = true
              redo
            else
              # If the token has expired and retry has already been attempted, raise a specific error
              raise DimensionsPublicationQueryError, 'Retry attempted after token refresh failed with 403 Forbidden error.'
            end
          else
            raise DimensionsPublicationQueryError, "Failed to retrieve UNC affiliated articles from dimensions. Status code #{response.code}, response body: #{response.body}"
          end
        rescue HTTParty::Error, StandardError => e
          retry if query_needs_retry?(e, retries)
          raise e
        end
      end
      return all_publications.to_a
    end

    def query_needs_retry?(e, retries)
      retries[0] += 1
      if retries[0] <= MAX_RETRIES
        Rails.logger.error("HTTParty error during Dimensions API query: #{e.message}")
        Rails.logger.warn("Retrying query after #{2**retries[0]} seconds. (Attempt #{retries[0]} of #{MAX_RETRIES})")
        sleep(2**retries[0]) # Using base 2 for exponential backoff
        return true
      end
      Rails.logger.error("Query failed after #{MAX_RETRIES} attempts. Exiting.")
      false
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

    def process_response(response)
      parsed_body = JSON.parse(response.body)
      # To disable deduplication during testing, comment out the next line and uncomment the following line. (Makes it easier to conduct repeated tests of the ingest process.)
      # publications = deduplicate_publications(parsed_body['publications'])
      publications = parsed_body['publications']
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

    def deduplicate_publications(publications)
      # Separate publications with and without DOI
      publications_with_doi, publications_without_doi = separate_publications_by_doi(publications)
      new_publications_with_doi = remove_duplicate_publications(publications_with_doi, :doi)
      new_publications_without_doi = remove_duplicate_publications(publications_without_doi)

      # Combine the new publications
      new_publications = new_publications_with_doi + new_publications_without_doi
      new_publications
    end

    def separate_publications_by_doi(publications)
      publications_with_doi = []
      publications_without_doi = []

      publications.each do |pub|
        if pub['doi'].present?
          publications_with_doi << pub
        else
          publications_without_doi << pub
        end
      end

      [publications_with_doi, publications_without_doi]
    end

    def remove_duplicate_publications(publications, type = :other)
      new_publications, removed_publications = publications.partition do |pub|
        query_string = type == :doi ? doi_query_string(pub['doi']) : solr_query_builder(pub)
        result = Hyrax::SolrService.get(query_string)
        result['response']['docs'].empty?
      end
      log_removed_publications(removed_publications, type)
      new_publications
    end

    def doi_query_string(doi)
      doi_tesim = "https://doi.org/#{doi}"
      "doi_tesim:\"#{doi_tesim}\" OR identifier_tesim:\"#{doi}\""
    end

    def log_removed_publications(publications, type)
      publications.each do |pub|
        if type == :doi
          Rails.logger.debug("Removed duplicate publication with DOI: #{pub['doi']} and title: #{pub['title']}")
        else
          Rails.logger.debug("Removed duplicate publication with title: #{pub['title']}")
        end
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

    # Query with paramaters to retrieve publications related to UNC
    def generate_query_string(start_date, end_date, page_size, cursor)
      search_clauses = ['where type = "article"', "date >= \"#{start_date}\"", "date < \"#{end_date}\""].join(' and ')
      return_fields = ['basics', 'extras', 'abstract', 'issn', 'publisher', 'journal_title_raw', 'linkout', 'concepts'].join(' + ')
      <<~QUERY
        search publications where doi in ["10.1183/13993003.01709-2016","10.1002/pbc.26302", "10.1089/jpm.2016.0271", "10.1016/j.fertnstert.2016.07.348", "10.1016/j.fertnstert.2016.07.490", "10.1096/fasebj.30.1_supplement.1149.15"]
        return publications[#{return_fields}]
      QUERY
    end
end
end
