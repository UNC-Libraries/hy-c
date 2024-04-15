# frozen_string_literal: true
module Tasks
  class DimensionsIngestService
    class DimensionsPublicationIngestError < StandardError
    end
   
    def ingest_dimensions_publications(publications)
      puts "[#{Time.now}] Ingesting publications from Dimensions."
      ingested_count = 0

      publications.each.with_index do |publication, index|
        # WIP: Remove Index Break Later
        # if index == 3
        #   break
        # end
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
    end

    def article_with_metadata(publication)
      art = Article.new
      art.title = [publication['title']]
      art.creators_attributes = publication['authors'].map.with_index { |author, index| [index,author_to_hash(author, index)] }.to_h
      art.funder = map_publication_funders(publication)
      art.date_issued = publication['date']
      art.abstract = [publication['abstract']].compact.presence
      art.resource_type = [publication['type']].compact.presence
      art.identifier = map_publication_identifiers(publication)
      art.publisher = [publication['publisher']].compact.presence
      art.journal_title = publication['journal_title_raw'].presence
      art.journal_volume = publication['volume'].presence
      art.journal_issue = publication['issue'].presence
      # == WIP: Version doesn't exist in the model
      # art.version = publication['type'].present? && publication['type'] == 'preprint' ? 'preprint' : nil
      # == WIP: Issn is an array of values from dim, but is a single value in the model
      # art.issn = [publication['issn']].compact.presence

      # puts "Article Inspector journal_title: #{art.journal_title.inspect}"
      # puts "Article Inspector journal_volume: #{art.journal_volume.inspect}"
      # puts "Article Inspector journal_issue: #{art.journal_issue.inspect}"
      art.save!
      art
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

    def map_publication_identifiers(publication)
      [
        publication['id'].present? ? "Dimensions ID: #{publication['id']}" : nil,
        publication['doi'].present? ? "DOI: https://dx.doi.org/#{publication['doi']}" : nil,
        publication['pmid'].present? ? "PMID: #{publication['pmid']}" : nil,
        publication['pmcid'].present? ? "PMCID: #{publication['pmcid']}" : nil,
      ].compact
    end

    def map_publication_funders(publication)
      publication['funders'].presence&.map do |funder|
        funder.map { |key, value| "#{key}: #{value}" if value.present? }.compact.join('||')
      end
    end

    def map_creators_attributes(publication)
      publication['authors'].map.with_index { |author, index| [index,author_to_hash(author, index)] }.to_h
    end
  end
    end
