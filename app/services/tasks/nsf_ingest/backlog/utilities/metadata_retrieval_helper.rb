# frozen_string_literal: true
module Tasks::NsfIngest::Backlog::Utilities::MetadataRetrievalHelper
  extend self
  SOURCES = %w[crossref openalex datacite].freeze
  def fetch_metadata_for_doi(source:, doi:)
    raise ArgumentError, 'DOI must be provided' if doi.blank?
    raise ArgumentError, "Source must be one of: #{SOURCES.join(', ')}" unless SOURCES.include?(source)

    base_url = case source
               when 'crossref' then 'https://api.crossref.org/works/'
               when 'openalex' then 'https://api.openalex.org/works/https://doi.org/'
               when 'datacite' then 'https://api.datacite.org/dois/'
               end

    puts "Retrieving #{source.capitalize} metadata for DOI: #{doi}"
    url = URI.join(base_url, CGI.escape(doi))
    res = HTTParty.get(url)

    return parse_response(res, source, doi) if res.code == 200

    Rails.logger.error("[MetadataRetrievalHelper] Failed to retrieve metadata from #{source.capitalize} "\
                       "for DOI #{doi}: HTTP #{res.code}")
    nil
  rescue => e
    Rails.logger.error("[MetadataRetrievalHelper] Error retrieving #{source.capitalize} metadata for DOI #{doi}: #{e.message}")
    nil
  end

  def parse_response(res, source, doi)
    parsed = JSON.parse(res.body)
    case source
    when 'crossref' then parsed['message']
    when 'openalex' then parsed
    when 'datacite' then parsed['data']
    end
  end

  def generate_openalex_abstract(openalex_metadata)
    return nil unless openalex_metadata&.dig('abstract_inverted_index').present?
    inverted_index = openalex_metadata['abstract_inverted_index']
    tokens = inverted_index.flat_map { |word, positions| positions.map { |pos| [word, pos] } }
    tokens.sort_by! { |_, pos| pos }
    tokens.map(&:first).join(' ')
  end

  def extract_keywords_from_openalex(metadata)
    concepts = Array(metadata['concepts']).map { |c| c['display_name'] }
    keywords = Array(metadata['keywords']).map { |k| k['display_name'] }
    (concepts + keywords).uniq
  end
end
