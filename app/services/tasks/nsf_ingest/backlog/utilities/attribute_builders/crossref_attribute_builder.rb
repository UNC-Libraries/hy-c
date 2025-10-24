# frozen_string_literal: true
module Tasks::NsfIngest::Backlog::Utilities
  class CrossrefAttributeBuilder < Tasks::IngestHelperUtils::BaseAttributeBuilder
    private

    def generate_authors
      metadata['author'].map.with_index do |author, i|
        res = {
          'name' => [author['family'], author['given']].compact.join(', '),
          'orcid' => author.dig('ORCID'),
          'index' => i.to_s
        }
        retrieve_author_affiliations(res, author)
        puts "WIP Inspect author: #{author.inspect}"
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

    def apply_additional_basic_attributes
      article.title = [metadata['title']&.first].compact.presence
      article.abstract = [metadata['openalex_abstract'] || metadata['datacite_abstract'] || 'N/A']
      article.date_issued = metadata['indexed']['date-time']
      article.publisher = [metadata['publisher']].compact.presence
      article.keyword = metadata['openalex_keywords'] || []
      article.funder = retrieve_funder_names
      puts "WIP Additional attributes: #{article.title.inspect}, date_issued: #{article.date_issued.inspect}, publisher: #{article.publisher.inspect}, keywords: #{article.keyword.inspect}, funders: #{article.funder.inspect}"
    end

    def set_identifiers
      article.identifier = format_publication_identifiers
      article.issn = retrieve_issn
      puts "WIP Alternate IDs: #{article.identifier.inspect}"
      puts "WIP ISSNs: #{article.issn.inspect}"
      puts "WIP DOI: #{article.doi}"
    end

    def format_publication_identifiers
      doi = metadata['DOI'].presence
      pmid, pmcid = retrieve_alt_ids_from_europe_pmc(doi)

      puts "WIP Retrieved alternate IDs from Europe PMC for DOI #{doi}: PMID=#{pmid}, PMCID=#{pmcid}"
      [
        pmid ? "PMID: #{pmid}" : nil,
        pmcid ? "PMCID: #{pmcid}" : nil,
        doi   ? "DOI: https://dx.doi.org/#{doi}" : nil
      ].compact
    end

    def retrieve_funder_names
      Array(metadata['funder']).map { |f| f['name'] }.compact.uniq
    end

    def retrieve_issn
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

    def retrieve_alt_ids_from_europe_pmc(doi)
      pmid, pmcid = nil, nil
      if doi.present?
        alternate_id_api_url = 'https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=DOI:'
        res = HTTParty.get(URI.join(alternate_id_api_url, doi, '&format=json'))
        if res.code == 200
          result = JSON.parse(res.body)
          if result['hitCount'].to_i > 0
            first_result = result.dig('resultList', 'result')&.first
            pmid = first_result['pmid'].presence
            pmcid = first_result['pmcid'].presence
          end
        else
          Rails.logger.error("[CrossrefAttributeBuilder] Failed to retrieve alternate IDs from Europe PMC for DOI #{doi}: HTTP #{res.code}")
        end
      end
      [pmid, pmcid]
    end

    def set_journal_attributes
      article.journal_title = extract_journal_title
      article.journal_volume = metadata['volume']&.presence
      article.journal_issue = metadata['journal-issue']&.dig('issue')&.presence
      article.page_start, article.page_end = extract_page_range(metadata)
      puts "WIP Journal attributes: #{article.journal_title}, volume: #{article.journal_volume}, issue: #{article.journal_issue}, pages: #{article.page_start}-#{article.page_end}"
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
