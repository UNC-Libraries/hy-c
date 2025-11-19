# frozen_string_literal: true
module Tasks::EricIngest::Backlog::Utilities::AttributeBuilders
  class EricAttributeBuilder < Tasks::IngestHelperUtils::BaseAttributeBuilder

    def get_date_issued
      pub_year = metadata['publicationdateyear']
      pub_year.present? ? DateTime.new(pub_year.to_i).strftime('%Y-%m-%d') : nil
    end

    private

    def generate_authors
      # Some ERIC records do not have authors
      return ['N/A'] unless metadata['author'].present?

      metadata['author'].map.with_index do |full_name, i|
        {
          'name' => full_name,
          'index' => i.to_s
        }
      end
    end

    def apply_additional_basic_attributes(article)
      article.title = [CGI.unescapeHTML(metadata['title'])]
      article.abstract = [metadata['description']] if metadata['description'].present?
      article.date_issued = get_date_issued
      article.keyword = metadata['subject'] if metadata['subject'].present?
      article.publisher = [metadata['publisher']] if metadata['publisher'].present?
    end

    def set_identifiers(article)
      identifiers = []
      if metadata['eric_id'].present?
        identifiers << "ERIC ID: #{metadata['eric_id']}"
      end

      if metadata['issn'].present?
        metadata['issn'].each do |issn|
         # remove the "ISSN-" prefix if present, and strip whitespace
          article.issn = [issn.sub(/^ISSN[-:\s]*/i, '').strip]
        end
      end
      article.identifier = identifiers
    end

    # Stubbed methods since ERIC metadata does not include these fields
    def set_journal_attributes(article); end
    def retrieve_author_affiliations(hash, author); end
    def format_publication_identifiers; end

    end
end
