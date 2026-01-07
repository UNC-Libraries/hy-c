# frozen_string_literal: true
module Tasks::IngestHelperUtils::SharedAttributeBuilders
  class OaiPmhAttributeBuilder < Tasks::IngestHelperUtils::BaseAttributeBuilder
    private

    def apply_additional_basic_attributes(article)
      article.title = [CGI.unescapeHTML(metadata['title'])] if metadata['title'].present?
      article.abstract = [CGI.unescapeHTML(metadata['abstract'])] if metadata['abstract'].present?
      article.date_issued = metadata['date_issued'] if metadata['date_issued'].present?
      # Publisher, keyword and funder info not typically available in OAI-PMH records
      article.publisher = []
      article.funder = []
      article.keyword = []
    end

    def generate_authors
      metadata['authors'].presence || [{ 'name' => 'The University of North Carolina at Chapel Hill', 'index' => '0' }]
    end

    def set_identifiers(article)
      # Intentionally empty. Set in subclass or during post processing
      []
    end

    def set_journal_attributes(article); end
    def retrieve_author_affiliations(hash, author); end
    def format_publication_identifiers; end
  end
end
