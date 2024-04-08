module Tasks
  class DimensionsIngestService
    class DimensionsPublicationIngestError < StandardError
    end
   
    def ingest_dimensions_publications(publications)
      puts "[#{Time.now}] Ingesting publications from Dimensions."
      ingested_count = 0

      publications.each do |publication|
        begin
        # Ingest the publication into the database
          ingest_publication(publication)
          ingested_count += 1
          rescue StandardError => e
            # Wip remove puts later
            puts "Error ingesting publication: #{e.message}"
            Rails.logger.error("Error ingesting publication: #{e.message}")
        end
      end
      ingested_count
    end

    def ingest_publication(publication)
    # Extract the publication attributes
      article_with_metadata(publication)
      puts "Ingesting publication: #{publication['title']}"
      puts "Article Inspector: #{article_with_metadata(publication)}"

      # work_attributes = {
      #   # title: publication['title'],
      #   # creator: publication['authors'],
      #   # funder: publication['funders'],
      #   # date: publication['date'],
      #   # abstract: publication['abstract'],
      #   version: publication['type'] == 'preprint' ? 'preprint' : nil,
      #   resource_type: publication['type'],
      #   identifier_tesim: [
      #     publication['id'].present? ? "Dimensions ID: #{publication['id']}" : nil,
      #     publication['doi'].present? ? "DOI: https://dx.doi.org/#{publication['doi']}" : nil,
      #     publication['pmid'].present? ? "PMID: #{publication['pmid']}" : nil,
      #     publication['pmcid'].present? ? "PMCID: #{publication['pmid']}" : nil,
      #   ].compact,
      #   issn: publication['issn'],
      #   publisher: publication['publisher'],
      #   journal_title: publication['journal_title_raw'],
      #   journal_volume: publication['volume'],
      #   journal_issue: publication['issue'],
      #   page_start: publication['pages'].present? && publication['pages'].include?('-') ? publication['pages'].split('-').first : nil,
      #   page_end: publication['pages'].present? && publication['pages'].include?('-') ? publication['pages'].split('-').last : nil,
      #   rights_statement: CdrRightsStatementsService.label('http://rightsstatements.org/vocab/InC/1.0/'),
      #   dcmi_type: DcmiTypeService.label('http://purl.org/dc/dcmitype/Text')
      # }
    end

    def article_with_metadata(publication)
      art = Article.new
      art.title = [publication['title']]
      # art.creator = publication['authors']
      # art.funder = publication['funders'].map { |funder| funder['name'] }
      # art.date_issued = publication['date']
      # art.abstract = publication['abstract']
      art.save!
      art
    end
  end
    end
