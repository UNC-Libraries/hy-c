module Tasks
  class DimensionsIngestService
    class DimensionsTokenRetrievalError < StandardError
    end
    class DimensionsPublicationIngestError < StandardError
    end
    DIMENSIONS_URL = 'https://app.dimensions.ai/api'

    def ingest_dimensions_publications(publications)
    # Initialize a counter to track the number of publications ingested
      ingested_count = 0

      publications.each do |publication|
        begin
        # Ingest the publication into the database
          puts "Ingesting publication: #{publication['title']}"
          ingested_count += 1
          rescue StandardError => e
            Rails.logger.error("Error ingesting publication: #{e.message}")
        end
      end

      ingested_count
    end

    # def ingest_publication(publication)
    # # Extract the publication attributes
    #   title = publication['title']
    #   doi = publication['doi']
    #   publication_date = publication['publication_date']
    #   journal_title = publication['journal_title']
    #   journal_issn = publication['journal_issn']
    #   journal_eissn = publication['journal_eissn']
    #   authors = publication['authors']
    #   dimensions_id = publication['id']

    # # Create or update the publication in the database
    #   Publication.find_or_create_by(dimensions_id: dimensions_id) do |pub|
    #     pub.title = title
    #     pub.doi = doi
    #     pub.publication_date = publication_date
    #     pub.journal_title = journal_title
    #     pub.journal_issn = journal_issn
    #     pub.journal_eissn = journal_eissn
    #     pub.authors = authors
    #   end
    # end
  end
    end
