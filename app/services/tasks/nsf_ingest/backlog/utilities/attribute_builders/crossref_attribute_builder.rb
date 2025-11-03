# frozen_string_literal: true
module Tasks::NsfIngest::Backlog::Utilities::AttributeBuilders
  class CrossrefAttributeBuilder < Tasks::IngestHelperUtils::BaseAttributeBuilder
    # Articles with extremely long author lists can cause indexing and UI issues
    TRUNCATED_AUTHORS_LIMIT = 275
    private

    def generate_authors
      if metadata['author'].size > TRUNCATED_AUTHORS_LIMIT
        Rails.logger.warn("[CrossrefAttributeBuilder] Author list exceeds #{TRUNCATED_AUTHORS_LIMIT} for article with DOI " \
                          "\"#{metadata['DOI']}\". Truncating author list to first #{TRUNCATED_AUTHORS_LIMIT} authors.")
        metadata['author'] = metadata['author'].first(TRUNCATED_AUTHORS_LIMIT)
      end
      metadata['author'].map.with_index do |author, i|
        res = {
          'name' => [author['family'], author['given']].compact.join(', '),
          'orcid' => author.dig('ORCID'),
          'index' => i.to_s
        }
        retrieve_author_affiliations(res, author)
        res
      end
    end

    def retrieve_author_affiliations(hash, author)
      affiliations = author['affiliation']&.map { |aff| aff['name'] } || []
      # Search for UNC affiliation
      unc_affiliation = affiliations.find { |aff| AffiliationUtilsHelper.is_unc_affiliation?(aff) }
      # Fallback to first affiliation if no UNC affiliation found
      hash['other_affiliation'] = unc_affiliation.presence || affiliations[0].presence || ''
    end

    def apply_additional_basic_attributes(article)
      article.title = [metadata['title']&.first].compact.presence
      article.abstract = [metadata['openalex_abstract'] || metadata['datacite_abstract'] || 'N/A']
      article.date_issued = metadata['indexed']['date-time']
      article.publisher = [metadata['publisher']].compact.presence
      article.keyword = metadata['openalex_keywords'] || []
      article.funder = retrieve_funder_names
    end

    def set_identifiers(article)
      article.identifier = format_publication_identifiers
      article.issn = retrieve_issn(article)
    end

    def format_publication_identifiers
      doi = metadata['DOI'].presence
      pmid, pmcid = retrieve_alt_ids_from_europe_pmc(doi)

      identifiers = []
      identifiers << "PMID: #{pmid}" if pmid.present?
      identifiers << "PMCID: #{pmcid}" if pmcid.present?
      identifiers << "DOI: https://dx.doi.org/#{doi}" if doi.present?
      identifiers
    end

    def retrieve_funder_names
      Array(metadata['funder']).map { |f| f['name'] }.compact.uniq
    end

    def retrieve_issn(article)
      issns = metadata['issn-type'] || []
      epub_issn = issns.find { |issn| issn['type'] == 'electronic' }&.dig('value').presence
      ppub_issn = issns.find { |issn| issn['type'] == 'print' }&.dig('value').presence
      if epub_issn
        [epub_issn]
      elsif ppub_issn
        Rails.logger.warn('[CrossrefAttributeBuilder] No electronic ISSN found for article with DOI ' \
                          "\"#{article.doi}\". Using Print ISSN.")
        [ppub_issn]
      else
        Rails.logger.warn('[CrossrefAttributeBuilder] No electronic or print ISSN found for article with DOI ' \
                          "\"#{article.doi}\". Skipping ISSN assignment.")
        []
      end
    end

    def set_journal_attributes(article)
      article.journal_title = extract_journal_title
      article.journal_volume = metadata['volume']&.presence
      article.journal_issue = metadata['journal-issue']&.dig('issue')&.presence
      article.page_start, article.page_end = extract_page_range(metadata)
    end

    def extract_page_range(msg)
      pages = msg['page']&.split('-')&.map(&:strip)
      return [nil, nil] if pages.blank?

      if pages.length == 1
        [pages.first, nil]
      else
        [pages.first, pages.last]
      end
    end

    def extract_journal_title
      Array(metadata['container-title']).first || Array(metadata['short-container-title']).first
    end
  end
end
