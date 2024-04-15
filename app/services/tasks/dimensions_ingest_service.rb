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
      art.funder = publication['funders'].presence&.map do |funder|
        funder.map { |key, value| "#{key}: #{value}" if value.present? }.compact.join('||')
      end
      # puts "Article Inspector: #{art.funder.inspect}"
      puts "Article Inspector: #{art.inspect}"
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
  end
    end
