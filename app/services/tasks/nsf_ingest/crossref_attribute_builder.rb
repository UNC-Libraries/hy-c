# frozen_string_literal: true
module Tasks
  module NsfIngest
    class CrossrefAttributeBuilder < BaseAttributeBuilder
      def get_date_issued
        metadata['indexed']['date-time'] ? DateTime.parse(metadata['indexed']['date-time']) : nil
      end

      private

      def apply_additional_basic_attributes
        article.title = [metadata['title']&.first].compact.presence
        article.abstract = [metadata['abstract'] || 'N/A']
        article.date_issued = get_date_issued
        article.publisher = [metadata['publisher']].compact.presence
        article.keyword = [metadata['subject']].flatten.compact.uniq
        article.funder = [metadata.dig('funder', 0, 'name')].compact.presence
        puts "WIP Additional attributes: #{article.title}, #{article.date_issued}, #{article.publisher}, #{article.funder}, keywords: #{article.keyword.inspect}, abstract: #{article.abstract}"
      end

      def generate_authors
        metadata['author'].map.with_index do |author, i|
          {
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
    end
  end
end
