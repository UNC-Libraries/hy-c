# frozen_string_literal: true
module Tasks
  module PubmedIngest
    class PubmedAttributeBuilder
      def find_skipped_row(metadata, new_pubmed_works)
        pmid = metadata.at_xpath('PubmedData/ArticleIdList/ArticleId[@IdType="pubmed"]')&.text
        pmcid = metadata.at_xpath('PubmedData/ArticleIdList/ArticleId[@IdType="pmc"]')&.text
        new_pubmed_works.find { |row| row['pmid'] == pmid || row['pmcid'] == pmcid }
      end

      def get_date_issued(metadata)
        pubdate = metadata.at_xpath('PubmedData/History/PubMedPubDate[@PubStatus="pubmed"]')
        year = pubdate&.at_xpath('Year')&.text || pubdate&.at_xpath('year')&.text
        month = pubdate&.at_xpath('Month')&.text || pubdate&.at_xpath('month')&.text || 1
        day = pubdate&.at_xpath('Day')&.text || pubdate&.at_xpath('day')&.text || 1
        DateTime.new(year.to_i, month.to_i, day.to_i).strftime('%Y-%m-%d')
      end

      def generate_authors(metadata)
        metadata.xpath('MedlineCitation/Article/AuthorList/Author').map.with_index do |author, i|
          res = {
          'name' => [author.xpath('LastName').text, author.xpath('ForeName').text].join(', '),
          'orcid' => author.at_xpath('Identifier[@Source="ORCID"]')&.text&.then { |id| "https://orcid.org/#{id}" } || '',
          'index' => i.to_s
          }
          self.retrieve_author_affiliations(res, author, metadata.name)
          res
        end
      end

      def set_identifiers(article, metadata)
        article.identifier = format_publication_identifiers(metadata)
        article.issn = [metadata.xpath('MedlineCitation/Article/Journal/ISSN[@IssnType="Electronic"]').text]
      end

      def set_journal_attributes(article, metadata)
        article.journal_title = metadata.at_xpath('MedlineCitation/Article/Journal/Title')&.text
        article.journal_volume = metadata.at_xpath('MedlineCitation/Article/Journal/JournalIssue/Volume')&.text.presence
        article.journal_issue = metadata.at_xpath('MedlineCitation/Article/Journal/JournalIssue/Issue')&.text.presence
        article.page_start = metadata.at_xpath('MedlineCitation/Article/Pagination/StartPage')&.text.presence
        article.page_end   = metadata.at_xpath('MedlineCitation/Article/Pagination/EndPage')&.text.presence
      end

      def apply_additional_basic_attributes(article, metadata)
        article.title = [metadata.xpath('MedlineCitation/Article/ArticleTitle').text]
        article.abstract = [metadata.xpath('MedlineCitation/Article/Abstract/AbstractText').text]
        article.date_issued = get_date_issued(metadata)
          # No explicit publisher in PubmedArticle XML
        article.publisher = []
        article.keyword = metadata.xpath('MedlineCitation/KeywordList/Keyword').map(&:text)
        article.funder = metadata.xpath('MedlineCitation/Article/GrantList/Grant/Agency').map(&:text)
      end

      private

      def retrieve_author_affiliations(hash, author, metadata_name)
        affiliations = author.xpath('AffiliationInfo/Affiliation').map(&:text)
            # Search for UNC affiliation
        unc_affiliation = affiliations.find { |aff| AffiliationUtilsHelper.is_unc_affiliation?(aff) }
            # Fallback to first affiliation if no UNC affiliation found
        hash['other_affiliation'] = unc_affiliation.presence || affiliations[0].presence || ''
      end

      def format_publication_identifiers(metadata)
        id_list = metadata.xpath('PubmedData/ArticleIdList')
        [
            (pmid = id_list.at_xpath('ArticleId[@IdType="pubmed"]')) ? "PMID: #{pmid.text}" : nil,
            (pmcid = id_list.at_xpath('ArticleId[@IdType="pmc"]')) ? "PMCID: #{pmcid.text}" : nil,
            (doi = id_list.at_xpath('ArticleId[@IdType="doi"]')) ? "DOI: https://dx.doi.org/#{doi.text}" : nil
        ].compact
      end
    end
  end
end
