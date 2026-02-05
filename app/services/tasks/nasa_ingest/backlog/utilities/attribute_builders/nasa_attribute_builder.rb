# frozen_string_literal: true
module Tasks::NASAIngest::Backlog::Utilities::AttributeBuilders
  class NASAAttributeBuilder < Tasks::IngestHelperUtils::BaseAttributeBuilder
    private

    def apply_additional_basic_attributes(article)
      article.title = [metadata['title']]
      article.abstract = [metadata['abstract'].presence || 'N/A']
      article.date_issued = Date.parse(metadata['distributionDate']).edtf if metadata['distributionDate'].present?
      article.keyword = metadata['keywords'] || []
      article.publisher = [metadata.dig('publications', 0, 'publisher')].compact.presence
    end

    def set_identifiers(article)
      identifiers = []
      nasa_id = metadata['id']
      # If NASA ID is present
      if nasa_id.present?
        identifiers << "NASA ID: #{nasa_id}"
      end
      article.identifier = identifiers
      article.issn = [metadata.dig('publications', 0, 'eissn')].compact.presence
      article.doi = metadata.dig('publications', 0, 'doi').presence
    end

    def generate_authors
      return [{ 'name' => 'The University of North Carolina at Chapel Hill', 'index' => '0' }] unless metadata['authorAffiliations'].present?

      metadata['authorAffiliations']
        .sort_by { |affil| affil['sequence'] }
        .map.with_index do |affil, i|
          author_name = affil.dig('meta', 'author', 'name')
          res ={
            'name' => author_name,
            'index' => i.to_s
          }
          retrieve_author_affiliations(res, affil)
          res
        end
    end

    def retrieve_author_affiliations(hash, affiliation_data)
      return unless affiliation_data

      org_name = affiliation_data.dig('meta', 'organization', 'name')
      hash['other_affiliation'] = [org_name] if org_name.present?
    end

    def set_journal_attributes(article)
      article.journal_title = metadata.dig('publications', 0, 'publicationName')
      article.journal_volume = metadata.dig('publications', 0, 'volume').presence
    end

    def format_publication_identifiers; end
  end
end
