# frozen_string_literal: true
module Tasks
    module PubmedIngest
        class PmcAttributeBuilder
            def find_skipped_row(metadata, new_pubmed_works)
                pmid = metadata.at_xpath('.//article-id[@pub-id-type="pmid"]')&.text
                pmcid = metadata.at_xpath('.//article-id[@pub-id-type="pmcid"]')&.text
                new_pubmed_works.find { |row| row['pmid'] == pmid || row['pmcid'] == pmcid }
            end

            def format_publication_identifiers(metadata)
                article_meta = metadata.at_xpath('front/article-meta')
                [
                    (pmid = article_meta.at_xpath('article-id[@pub-id-type="pmid"]')) ? "PMID: #{pmid.text}" : nil,
                    (pmcid = article_meta.at_xpath('article-id[@pub-id-type="pmcid"]')) ? "PMCID: #{pmcid.text}" : nil,
                    (doi = article_meta.at_xpath('article-id[@pub-id-type="doi"]')) ? "DOI: https://dx.doi.org/#{doi.text}" : nil
                ].compact
            end

            def get_date_issued(metadata)
                pubdate = metadata.at_xpath('front/article-meta/pub-date[@pub-type="epub"]')
                year = pubdate&.at_xpath('Year')&.text || pubdate&.at_xpath('year')&.text
                month = pubdate&.at_xpath('Month')&.text || pubdate&.at_xpath('month')&.text || 1
                day = pubdate&.at_xpath('Day')&.text || pubdate&.at_xpath('day')&.text || 1
                DateTime.new(year.to_i, month.to_i, day.to_i).strftime('%Y-%m-%d')
            end

            def retrieve_author_affiliations(hash, author, metadata_name)
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
        end
    end
end
