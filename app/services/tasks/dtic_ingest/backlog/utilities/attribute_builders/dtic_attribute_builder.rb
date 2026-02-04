# frozen_string_literal: true
module Tasks::DTICIngest::Backlog::Utilities::AttributeBuilders
  class DTICAttributeBuilder < Tasks::IngestHelperUtils::BaseAttributeBuilder
    private

    def apply_additional_basic_attributes(article)
      article.title = [metadata['title']]
      article.abstract = [metadata['subject']] if metadata['subject'].present?
      article.date_issued = Date.parse(metadata['content_date']).edtf if metadata['content_date'].present?
    end

    def set_identifiers(article)
      identifiers = []
      dtic_id = metadata['filename'].split('.').first
      # If DTIC ID is present, and contains numbers, set as identifier
      if dtic_id.present? && dtic_id.match?(/\d/)
        identifiers << "DTIC ID: #{dtic_id}"
      end
      article.identifier = identifiers
    end

    def generate_authors
      # Fallback to single institutional author if no authors listed
      return [{ 'name' => 'The University of North Carolina at Chapel Hill', 'index' => '0' }] unless metadata['author'].present?

      authors = metadata['author'].split(';').map(&:strip)
      authors.map.with_index do |full_name, i|
        {
          'name' => full_name,
          'index' => i.to_s
        }
      end
    end

    def set_journal_attributes(article); end
    def retrieve_author_affiliations(hash, author); end
    def format_publication_identifiers; end
  end
end
