# frozen_string_literal: true
module Tasks::NsfIngest::Backlog::Utilities::AttributeBuilders
  class OpenalexAttributeBuilder < Tasks::IngestHelperUtils::BaseAttributeBuilder
    private

    def generate_authors
      metadata['authorships'].map.with_index do |obj, i|
        author = obj['author']
        res = {
          'name' => format_author_name(author['display_name']),
          'orcid' => author.dig('orcid'),
          'index' => i.to_s
        }
        retrieve_author_affiliations(res, author)
        puts "WIP Inspect author: #{author.inspect}"
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

    def apply_additional_basic_attributes
      article.title = [metadata['title']].compact.presence
      article.abstract = [metadata['openalex_abstract'] || 'N/A']
      # ('%Y-%m-%dT00:00:00Z')
      article.date_issued = DateTime.parse(metadata['publication_date']).strftime('%Y-%m-%dT00:00:00Z')
      article.publisher = [metadata.dig('primary_location', 'source', 'host_organization_name')]
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
      doi =  metadata['doi'].present? ? WorkUtilsHelper.normalize_doi(metadata['doi']) : nil
      pmid, pmcid = retrieve_alt_ids_from_europe_pmc(doi)

      puts "WIP Retrieved alternate IDs from Europe PMC for DOI #{doi}: PMID=#{pmid}, PMCID=#{pmcid}"
      [
        pmid ? "PMID: #{pmid}" : nil,
        pmcid ? "PMCID: #{pmcid}" : nil,
        doi   ? "DOI: https://dx.doi.org/#{doi}" : nil
      ].compact
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

    def set_journal_attributes
      source = metadata.dig('primary_location', 'source')
      biblio = metadata['biblio'] || {}

      article.journal_title = source&.dig('display_name')
      article.journal_volume = biblio['volume'].presence
      article.journal_issue = biblio['issue'].presence
      article.page_start = biblio['first_page'].presence
      article.page_end = biblio['last_page'].presence

      puts "WIP Journal attributes (OpenAlex): #{article.journal_title}, "\
       "volume: #{article.journal_volume}, issue: #{article.journal_issue}, "\
       "pages: #{article.page_start}-#{article.page_end}"
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
