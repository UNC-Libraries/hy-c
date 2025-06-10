# frozen_string_literal: true
module Tasks
  module PubmedIngest
    class PubmedAttributeBuilder < BaseAttributeBuilder

      def find_skipped_row(new_pubmed_works)
        Rails.logger.info("[PubMed] Finding skipped row for article: #{article.title}")
        pmid = metadata.at_xpath('PubmedData/ArticleIdList/ArticleId[@IdType="pubmed"]')&.text
        pmcid = metadata.at_xpath('PubmedData/ArticleIdList/ArticleId[@IdType="pmc"]')&.text
        Rails.logger.info("[PubMed] Searching for PMID: #{pmid}, PMCID: #{pmcid} in new works")
        Rails.logger.info("[PubMed] Raw PMID #{metadata.at_xpath('PubmedData/ArticleIdList/ArticleId[@IdType="pubmed"]').inspect}")
        Rails.logger.info("[PubMed] Raw PMCID #{metadata.at_xpath('PubmedData/ArticleIdList/ArticleId[@IdType="pmc"]').inspect}")
        new_pubmed_works.find { |row| row['pmid'] == pmid || row['pmcid'] == pmcid }
      end

      private

      def generate_authors
        metadata.xpath('MedlineCitation/Article/AuthorList/Author').map.with_index do |author, i|
          res = {
            'name' => [author.xpath('LastName').text, author.xpath('ForeName').text].join(', '),
            'orcid' => author.at_xpath('Identifier[@Source="ORCID"]')&.text&.then { |id| "https://orcid.org/#{id}" } || '',
            'index' => i.to_s
          }
          retrieve_author_affiliations(res, author)
          res
        end
      end

      def retrieve_author_affiliations(hash, author)
        affiliations = author.xpath('AffiliationInfo/Affiliation').map(&:text)
        # Search for UNC affiliation
        unc_affiliation = affiliations.find { |aff| AffiliationUtilsHelper.is_unc_affiliation?(aff) }
        # Fallback to first affiliation if no UNC affiliation found
        hash['other_affiliation'] = unc_affiliation.presence || affiliations[0].presence || ''
      end

      def apply_additional_basic_attributes
        article.title = [metadata.xpath('MedlineCitation/Article/ArticleTitle').text]
        article.abstract = [metadata.xpath('MedlineCitation/Article/Abstract/AbstractText').text]
        article.date_issued = get_date_issued
        article.publisher = [] # No explicit publisher in PubMed XML
        article.keyword = metadata.xpath('MedlineCitation/KeywordList/Keyword').map(&:text)
        article.funder = metadata.xpath('MedlineCitation/Article/GrantList/Grant/Agency').map(&:text)
      end

      def get_date_issued
        pubdate = metadata.at_xpath('PubmedData/History/PubMedPubDate[@PubStatus="pubmed"]')
        year = pubdate&.at_xpath('Year')&.text
        month = pubdate&.at_xpath('Month')&.text || 1
        day = pubdate&.at_xpath('Day')&.text || 1
        DateTime.new(year.to_i, month.to_i, day.to_i).strftime('%Y-%m-%d')
      end

      def set_identifiers
        article.identifier = format_publication_identifiers
        article.issn = [metadata.at_xpath('MedlineCitation/Article/Journal/ISSN[@IssnType="Electronic"]')&.text.presence || 'NONE']
      end

      def format_publication_identifiers
        id_list = metadata.xpath('PubmedData/ArticleIdList')

        pmid_node  = id_list.at_xpath('ArticleId[@IdType="pubmed"]')
        pmcid_node = id_list.at_xpath('ArticleId[@IdType="pmc"]')
        doi_node   = id_list.at_xpath('ArticleId[@IdType="doi"]')

        [
          pmid_node  ? "PMID: #{pmid_node.text}" : nil,
          pmcid_node ? "PMCID: #{pmcid_node.text}" : nil,
          doi_node   ? "DOI: https://dx.doi.org/#{doi_node.text}" : nil
        ].compact
      end


      def set_journal_attributes
        article.journal_title = metadata.at_xpath('MedlineCitation/Article/Journal/Title')&.text
        article.journal_volume = metadata.at_xpath('MedlineCitation/Article/Journal/JournalIssue/Volume')&.text.presence
        article.journal_issue = metadata.at_xpath('MedlineCitation/Article/Journal/JournalIssue/Issue')&.text.presence
        article.page_start = metadata.at_xpath('MedlineCitation/Article/Pagination/StartPage')&.text.presence
        article.page_end   = metadata.at_xpath('MedlineCitation/Article/Pagination/EndPage')&.text.presence
      end
    end
  end
end
