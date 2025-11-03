# frozen_string_literal: true
module Tasks::NsfIngest::Backlog::Utilities::AttributeBuilders
  class OpenalexAttributeBuilder < Tasks::IngestHelperUtils::BaseAttributeBuilder
    TRUNCATED_AUTHORS_LIMIT = 100
    private

    def generate_authors
      if metadata['authorships'].size > TRUNCATED_AUTHORS_LIMIT
        Rails.logger.warn("[OpenalexAttributeBuilder] Author list exceeds 100 authors for article with
                          \"#{metadata['doi']}\". Truncating author list to first #{TRUNCATED_AUTHORS_LIMIT} authors.")
        metadata['authorships'] = metadata['authorships'].first(TRUNCATED_AUTHORS_LIMIT)
      end
      metadata['authorships'].map.with_index do |obj, i|
        author = obj['author']
        res = {
          'name' => format_author_name(author['display_name']),
          'orcid' => author.dig('orcid'),
          'index' => i.to_s
        }
        retrieve_author_affiliations(res, author)
        res
      end
    end

    def retrieve_author_affiliations(hash, author)
      affiliations = author['institutions']&.map { |aff| aff['display_name'] } || []
      # Search for UNC affiliation
      unc_affiliation = affiliations.find { |aff| AffiliationUtilsHelper.is_unc_affiliation?(aff) }
      # Fallback to first affiliation if no UNC affiliation found
      hash['other_affiliation'] = unc_affiliation.presence || affiliations[0].presence || ''
    end

    def apply_additional_basic_attributes(article)
      article.title = [metadata['title']].compact.presence
      article.abstract = [metadata['openalex_abstract'] || 'N/A']
      # ('%Y-%m-%dT00:00:00Z')
      article.date_issued = DateTime.parse(metadata['publication_date']).strftime('%Y-%m-%dT00:00:00Z')
      article.publisher = [metadata.dig('primary_location', 'source', 'host_organization_name')].compact.presence
      article.keyword = metadata['openalex_keywords'] || []
      article.funder = retrieve_funder_names
    end

    def set_identifiers(article)
      article.identifier = format_publication_identifiers
      article.issn = retrieve_issn
    end

    def format_publication_identifiers
      doi =  metadata['doi'].present? ? WorkUtilsHelper.normalize_doi(metadata['doi']) : nil
      pmid, pmcid = retrieve_alt_ids_from_europe_pmc(doi)

      identifiers = []
      identifiers << "PMID: #{pmid}" if pmid.present?
      identifiers << "PMCID: #{pmcid}" if pmcid.present?
      identifiers << "DOI: https://dx.doi.org/#{doi}" if doi.present?
      identifiers
    end

    def retrieve_funder_names
      Array(metadata['grants']).map { |f| f['funder_display_name'] }.compact.uniq
    end

    def retrieve_issn
      # No different types of ISSNs in OpenAlex metadata, just return one from the primary location if available
      source = metadata.dig('primary_location', 'source')
      return [] if source.blank?

      issn = source['issn_l'].presence
      issn ? [issn] : []
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

    def set_journal_attributes(article)
      source = metadata.dig('primary_location', 'source')
      biblio = metadata['biblio'] || {}

      article.journal_title = source&.dig('display_name')
      article.journal_volume = biblio['volume'].presence
      article.journal_issue = biblio['issue'].presence
      article.page_start = biblio['first_page'].presence
      article.page_end = biblio['last_page'].presence
    end

    def format_author_name(display_name)
      return '' if display_name.blank?

      # Split by spaces, handle middle initials, multi-part last names, etc.
      parts = display_name.strip.split(/\s+/)
      return display_name if parts.size == 1

      last_name = parts.pop
      first_names = parts.join(' ')
      "#{last_name}, #{first_names}"
    end
  end
end
