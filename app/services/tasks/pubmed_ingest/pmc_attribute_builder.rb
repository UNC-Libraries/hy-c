# frozen_string_literal: true
module Tasks
  module PubmedIngest
    class PmcAttributeBuilder < BaseAttributeBuilder

      def find_skipped_row(new_pubmed_works)
        pmid = metadata.at_xpath('.//article-id[@pub-id-type="pmid"]')&.text
        pmcid = metadata.at_xpath('.//article-id[@pub-id-type="pmcid"]')&.text
        new_pubmed_works.find { |row| row['pmid'] == pmid || row['pmcid'] == pmcid }
      end

      private

      def generate_authors
        metadata.xpath('front/article-meta/contrib-group/contrib[@contrib-type="author"]').map.with_index do |author, i|
          res = {
            'name' => [author.xpath('name/surname').text, author.xpath('name/given-names').text].join(', '),
            'orcid' => author.at_xpath('contrib-id[@contrib-id-type="orcid"]')&.text.to_s || '',
            'index' => i.to_s
          }
          retrieve_author_affiliations(res, author)
          res
        end
      end

      def retrieve_author_affiliations(hash, author)
        contrib_group = author.ancestors('contrib-group').first
        affiliations = author.xpath('aff/institution').map(&:text)

        if affiliations.empty? && contrib_group
          author_affiliation_ids = author.xpath('xref[@ref-type="aff"]').map { |n| n['rid'] }
          if author_affiliation_ids.any?
          # Regex to remove trailing comma and whitespace
            affiliations = author_affiliation_ids.map do |id|
              nodes = contrib_group.xpath("aff[@id='#{id}']/institution-wrap/institution")
              nodes.map(&:text).join.sub(/,\s*\z/, '')
            end
          else
            affiliations = contrib_group.xpath('aff').map(&:text)
          end
        end
          # Search for UNC affiliation
        unc_affiliation = affiliations.find { |aff| AffiliationUtilsHelper.is_unc_affiliation?(aff) }
          # Fallback to first affiliation if no UNC affiliation found
        hash['other_affiliation'] = unc_affiliation.presence || affiliations[0].presence || ''
      end

      def apply_additional_basic_attributes
        article.title = [metadata.xpath('front/article-meta/title-group/article-title').text]
        article.abstract = [metadata.xpath('front/article-meta/abstract').text]
        article.date_issued = get_date_issued
        article.publisher = [metadata.at_xpath('front/journal-meta/publisher/publisher-name')&.text].compact.presence
        article.keyword = metadata.xpath('//kwd-group/kwd').map(&:text)
        article.funder = metadata.xpath('//funding-source/institution-wrap/institution').map(&:text)
      end

      def get_date_issued
        pubdate = metadata.at_xpath('front/article-meta/pub-date[@pub-type="epub"]')
        year  = pubdate&.at_xpath('year')&.text
        month = pubdate&.at_xpath('month')&.text || 1
        day   = pubdate&.at_xpath('day')&.text || 1
        DateTime.new(year.to_i, month.to_i, day.to_i).strftime('%Y-%m-%d')
      end

      def set_identifiers
        article.identifier = format_publication_identifiers
        article.issn = [metadata.xpath('front/journal-meta/issn[@pub-type="epub"]').text.presence || 'NONE']
      end

      def format_publication_identifiers
        article_meta = metadata.at_xpath('front/article-meta')
        [
          (pmid  = article_meta.at_xpath('article-id[@pub-id-type="pmid"]'))  ? "PMID: #{pmid.text}" : nil,
          (pmcid = article_meta.at_xpath('article-id[@pub-id-type="pmcid"]')) ? "PMCID: #{pmcid.text}" : nil,
          (doi   = article_meta.at_xpath('article-id[@pub-id-type="doi"]'))   ? "DOI: https://dx.doi.org/#{doi.text}" : nil
        ].compact
      end

      def set_journal_attributes
        article.journal_title = metadata.at_xpath('front/journal-meta/journal-title-group/journal-title')&.text.presence
        article.journal_volume = metadata.at_xpath('front/article-meta/volume')&.text.presence
        article.journal_issue = metadata.at_xpath('front/article-meta/issue-id')&.text.presence
        article.page_start     = metadata.at_xpath('front/article-meta/fpage')&.text.presence
        article.page_end       = metadata.at_xpath('front/article-meta/lpage')&.text.presence
      end
    end
  end
end
