# frozen_string_literal: true
module Tasks::RosapIngest::Backlog::Utilities::AttributeBuilders
  class RosapAttributeBuilder < Tasks::IngestHelperUtils::BaseAttributeBuilder
    private

    def apply_additional_basic_attributes(article)
      article.title = [CGI.unescapeHTML(metadata['title'])]
      article.abstract = [metadata['abstract']] if metadata['abstract'].present?
      article.date_issued = metadata['date_issued'] if metadata['date_issued'].present?
      article.keyword = metadata['keywords'] if metadata['keywords'].present?
      article.publisher = [metadata['publisher']] if metadata['publisher'].present?
    end

    def set_identifiers(article)
      identifiers = []
      if metadata['rosap_id'].present?
        identifiers << "ROSA-P ID: #{metadata['rosap_id']}"
      end

      if metadata['issn'].present?
        metadata['issn'].each do |issn|
        # remove the "ISSN-" prefix if present, and strip whitespace
          article.issn = [issn.sub(/^ISSN[-:\s]*/i, '').strip]
        end
      end
      article.identifier = identifiers
    end

      # Stubbed methods WIP
    def generate_authors; end
    def set_journal_attributes(article); end
    def retrieve_author_affiliations(hash, author); end
    def format_publication_identifiers; end
  end
end
