# frozen_string_literal: true
module Tasks
  class DimensionsIngestService
    class DimensionsPublicationIngestError < StandardError
    end
   
    def ingest_publications(publications)
      puts "[#{Time.now}] Ingesting publications from Dimensions."
      ingested_count = 0

      publications.each.with_index do |publication, index|
        begin
        # WIP: Remove Index Break Later
          if index == 3
            break
          end
          article_with_metadata(publication)
          ingested_count += 1
          rescue StandardError => e
            raise DimensionsPublicationIngestError, "Error ingesting publication: #{e.message}"
        end
      end
      ingested_count
    end

    def article_with_metadata(publication)
      article = Article.new
      populate_article_metadata(article, publication)
      puts "Article Inspector: #{article.inspect}"
      article.save!
      article
    end

    def populate_article_metadata(article, publication)
      set_basic_attributes(article, publication)
      set_journal_attributes(article, publication)
      set_rights_and_types(article, publication)
    end

    def set_basic_attributes(article, publication)
      article.title = [publication['title']]
      article.creators_attributes = publication['authors'].map.with_index { |author, index| [index,author_to_hash(author, index)] }.to_h
      article.funder = format_funders_data(publication)
      article.date_issued = publication['date']
      article.abstract = [publication['abstract']].compact.presence
      article.resource_type = [publication['type']].compact.presence
      article.publisher = [publication['publisher']].compact.presence
    end

    def set_rights_and_types(article, publication)
      article.rights_statement = CdrRightsStatementsService.label('http://rightsstatements.org/vocab/InC/1.0/')
      article.dcmi_type = [DcmiTypeService.label('http://purl.org/dc/dcmitype/Text')]
      article.edition = determine_edition(publication)
    end

    def set_journal_attributes(article, publication)
      article.journal_title = publication['journal_title_raw'].presence
      article.journal_volume = publication['volume'].presence
      article.journal_issue = publication['issue'].presence
      article.page_start, article.page_end = parse_page_numbers(publication).values_at(:start, :end)
    end

    def set_identifiers(article, publication)
      article.identifier = format_publication_identifiers(publication)
      article.issn = publication['issn'].presence
    end
  

    def author_to_hash(author, index)
      hash = {
        'name' => "#{[author['first_name'], author['last_name']].compact.join(' ')}",
        'orcid' => author['orcid'].present? ? author['orcid'] : '',
        'index' => (index + 1).to_s,
      }
      # Splitting author affiliations into UNC and other affiliations and adding them to hash
      if author['affiliations'].present?
        unc_grid_id = 'grid.410711.2'
        author_unc_affiliation = author['affiliations'].select { |affiliation| affiliation['id'] == unc_grid_id || 
                                                                  affiliation['raw_affiliation'].include?('UNC') ||
                                                                  affiliation['raw_affiliation'].include?('University of North Carolina, Chapel Hill')}.first
        author_other_affiliations = author['affiliations'].reject { |affiliation| affiliation['id'] == unc_grid_id || 
                                                                  affiliation['raw_affiliation'].include?('UNC') ||
                                                                  affiliation['raw_affiliation'].include?('University of North Carolina, Chapel Hill')}
        hash['other_affiliation'] = author_other_affiliations.map { |affiliation| affiliation['raw_affiliation'] }
        hash['affiliation'] = author_unc_affiliation.present? ? author_unc_affiliation['raw_affiliation'] : ''
      end
      hash
    end

    def format_publication_identifiers(publication)
      [
        publication['id'].present? ? "Dimensions ID: #{publication['id']}" : nil,
        publication['doi'].present? ? "DOI: https://dx.doi.org/#{publication['doi']}" : nil,
        publication['pmid'].present? ? "PMID: #{publication['pmid']}" : nil,
        publication['pmcid'].present? ? "PMCID: #{publication['pmcid']}" : nil,
      ].compact
    end

    def format_funders_data(publication)
      publication['funders'].presence&.map do |funder|
        funder.map { |key, value| "#{key}: #{value}" if value.present? }.compact.join('||')
      end
    end

    def parse_page_numbers(publication)
      return { start: nil, end: nil } unless publication['pages'].present?
      
      pages = publication['pages'].split('-')
      {
        start: pages.first,
        end: (pages.length == 2 ? pages.last : nil)
      }
    end

    def determine_edition(publication)
      publication['type'].present? && publication['type'] == 'preprint' ? 'preprint' : nil
    end

    def extract_pdf(publication)
      pdf_url = publication['linkout']
      return nil unless pdf_url.present?
      
      response = HTTParticley.head(pdf_url)
      return nil unless response.headers['content-type'].include?('application/pdf')

      pdf_file = Tempfile.new(['temp_pdf', '.pdf'])
      pdf_file.binmode
      pdf_file.write(HTTParticley.get(pdf_url).body)
      pdf_file.rewind
      pdf_file
    end

  

  end
    end
