# frozen_string_literal: true
module Tasks
  class DimensionsIngestService
    class DimensionsPublicationIngestError < StandardError
    end
   
    def ingest_dimensions_publications(publications)
      puts "[#{Time.now}] Ingesting publications from Dimensions."
      ingested_count = 0

      publications.each do |publication|
        begin
          ingest_publication(publication)
          ingested_count += 1
          rescue StandardError => e
            raise DimensionsPublicationIngestError, "Error ingesting publication: #{e.message}"
        end
      end
      ingested_count
    end

    def ingest_publication(publication)
      article_with_metadata(publication)
      # WIP: Remove Comments Later
      # puts "Ingesting publication: #{publication['title']}"
      # puts "Article Inspector: #{article_with_metadata(publication)}"

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
      placeholder_creators_variable = publication['authors'].map.with_index { |author, index| [index,author_to_hash(author, index)] }.to_h
      puts "Article Inspector: #{placeholder_creators_variable}"
      # WIP: Remove Comments Later
      # art.creators_attributes = placeholder
      # puts "Article Inspector: #{art.creators_attributes}"
      # art.funder = publication['funders'].map { |funder| funder['name'] }
      # art.date_issued = publication['date']
      # art.abstract = publication['abstract']
      art.save!
      art
    end

    def author_to_hash(author, index)
      hash = {
        # 'name' => 'placeholder',
        # 'orcid' => 'placeholder',
        # 'affiliation' => '',
        # 'affiliation' => some_method, # Do not store affiliation until we can map it to the controlled vocabulary
        'other_affiliation' => '',
        # 'index' => (index + 1).to_s
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
  end
    end
