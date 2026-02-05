# frozen_string_literal: true
module Tasks::NASAIngest::Backlog::Utilities::AttributeBuilders
  class NASAAttributeBuilder < Tasks::IngestHelperUtils::BaseAttributeBuilder
    private

    def apply_additional_basic_attributes(article)
      article.title = [metadata['title']]
      article.abstract = [metadata['abstract'].presence || 'N/A']
      article.date_issued = Date.parse(metadata['content_date']).edtf if metadata['content_date'].present?
    end

    def set_identifiers(article)
      identifiers = []
      nasa_id = metadata.dig('exportControl', 'submissionId')
      # If NASA ID is present
      if nasa_id.present?
        identifiers << "NASA ID: #{nasa_id}"
      end
      article.identifier = identifiers
    end

    def generate_authors
      # Fallback to single institutional author if no authors listed
      return [{ 'name' => 'The University of North Carolina at Chapel Hill', 'index' => '0' }] unless metadata['authorAffiliations'].present?

      authors = metadata['authorAffiliations']
      authors.map.with_index do |full_name, i|
        # Ensure space after comma in names
        normalized_name = full_name.gsub(/,(?!\s)/, ', ')
        {
          'name' => normalized_name,
          'index' => i.to_s
        }
      end
    end

    def set_journal_attributes(article); end
    def retrieve_author_affiliations(hash, author); end
    def format_publication_identifiers; end
  end
end