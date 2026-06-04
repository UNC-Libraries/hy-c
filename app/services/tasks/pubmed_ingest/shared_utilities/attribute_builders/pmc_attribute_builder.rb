# frozen_string_literal: true
module Tasks
  module PubmedIngest
    module SharedUtilities
      module AttributeBuilders
        class PmcAttributeBuilder < Tasks::IngestHelperUtils::BaseAttributeBuilder
          include Tasks::PubmedIngest::SharedUtilities::PmcS3VersionLookup

          PMC_LICENSE_CODE_TO_URI = {
            'CC BY' => 'http://creativecommons.org/licenses/by/4.0/',
            'CC BY-SA' => 'http://creativecommons.org/licenses/by-sa/4.0/',
            'CC BY-ND' => 'http://creativecommons.org/licenses/by-nd/4.0/',
            'CC BY-NC' => 'http://creativecommons.org/licenses/by-nc/4.0/',
            'CC BY-NC-SA' => 'http://creativecommons.org/licenses/by-nc-sa/4.0/',
            'CC BY-NC-ND' => 'http://creativecommons.org/licenses/by-nc-nd/4.0/'
          }.freeze

          def find_skipped_row(new_pubmed_works, article)
            pmid = metadata.at_xpath('.//article-id[@pub-id-type="pmid"]')&.text
            pmcid = metadata.at_xpath('.//article-id[@pub-id-type="pmcid"]')&.text
            new_pubmed_works.find { |row| row['pmid'] == pmid || row['pmcid'] == pmcid }
          end

          def get_date_issued
            pubdate = metadata.at_xpath('front/article-meta/pub-date[@pub-type="epub"]')
            year  = pubdate&.at_xpath('year')&.text
            month = pubdate&.at_xpath('month')&.text || 1
            day   = pubdate&.at_xpath('day')&.text || 1
            DateTime.new(year.to_i, month.to_i, day.to_i)
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

          def apply_additional_basic_attributes(article)
            article.title = [metadata.xpath('front/article-meta/title-group/article-title').text]
            article.abstract = [metadata.xpath('front/article-meta/abstract').text.presence || 'N/A']
            article.date_issued = get_date_issued.strftime('%Y-%m-%d')
            article.publisher = [metadata.at_xpath('front/journal-meta/publisher/publisher-name')&.text].compact.presence
            article.keyword = metadata.xpath('//kwd-group/kwd').map(&:text)
            article.funder = metadata.xpath('//funding-source/institution-wrap/institution').map(&:text)

            apply_json_metadata(article)
          end

          def apply_json_metadata(article)
            pmcid = metadata.at_xpath('.//article-id[@pub-id-type="pmcid"]')&.text
            return article unless pmcid.present?

            json_metadata = fetch_json_metadata(pmcid)
            return article unless json_metadata.present?

            # Map PMC license codes to repository-controlled license URIs.
            license_code = json_metadata['license_code']
            apply_license_from_code(article, license_code, pmcid)

            # Add edition as Postprint if is_manuscript is true
            if json_metadata['is_manuscript'] == true
              article.edition = 'Postprint'
            end

            article
          rescue => e
            Rails.logger.warn("[PMC] Failed to fetch or process JSON metadata for PMCID #{pmcid}: #{e.message}")
          end

          def fetch_json_metadata(pmcid)
            version_prefix = latest_version_prefix(pmcid)
            return nil unless version_prefix.present?

            version_id = version_prefix.chomp('/')
            json_url = "#{PMC_S3_BASE_URL}/#{version_prefix}#{version_id}.json"

            response = HTTParty.get(json_url, timeout: 30)
            return nil unless response.code == 200

            JSON.parse(response.body)
          rescue => e
            Rails.logger.warn("[PMC] Error fetching JSON from S3: #{e.message}")
            nil
          end

          # Keep version lookup internal to this builder even though it comes from a shared module.
          private :latest_version_prefix

          def license_uri_for_code(license_code)
            PMC_LICENSE_CODE_TO_URI[license_code]
          end

          def apply_license_from_code(article, license_code, pmcid)
            return if license_code.blank? || license_code == 'TDM'

            license_uri = license_uri_for_code(license_code)
            if license_uri.present?
              article.license = [license_uri]
              article.license_label = [CdrLicenseService.label(license_uri)]
            else
              Rails.logger.warn("[PMC] Unmapped license code '#{license_code}' for PMCID #{pmcid}")
            end
          end

          def set_identifiers(article)
            article.identifier = format_publication_identifiers
            epub_issn = metadata.at_xpath('front/journal-meta/issn[@pub-type="epub"]')&.text.presence
            ppub_issn = metadata.at_xpath('front/journal-meta/issn[@pub-type="ppub"]')&.text.presence
            doi = metadata.at_xpath('front/article-meta/article-id[@pub-id-type="doi"]')&.text.presence
            article.doi = doi if doi

            # Fallback logic for ISSN
            if epub_issn
              article.issn = [epub_issn]
            elsif ppub_issn
              Rails.logger.warn('[PMC] No epub ISSN found for article with identifiers ' \
                                "\"#{article.identifier.inspect}\". Using Print ISSN.")
              article.issn = [ppub_issn]
            else
              Rails.logger.warn('[PMC] No epub or ppub ISSN found for article with identifiers ' \
                                "\"#{article.identifier.inspect}\". Skipping ISSN assignment.")
            end
          end

          def format_publication_identifiers

            pmid_node  = metadata.at_xpath('front/article-meta/article-id[@pub-id-type="pmid"]')
            pmcid_node = metadata.at_xpath('front/article-meta/article-id[@pub-id-type="pmcid"]')
            doi_node   = metadata.at_xpath('front/article-meta/article-id[@pub-id-type="doi"]')

            [
              pmid_node  ? "PMID: #{pmid_node.text}" : nil,
              pmcid_node ? "PMCID: #{pmcid_node.text}" : nil,
              doi_node   ? "DOI: https://dx.doi.org/#{doi_node.text}" : nil
            ].compact
          end


          def set_journal_attributes(article)
            article.journal_title = metadata.at_xpath('front/journal-meta/journal-title-group/journal-title')&.text.presence
            article.journal_volume = metadata.at_xpath('front/article-meta/volume')&.text.presence
            article.journal_issue = metadata.at_xpath('front/article-meta/issue-id')&.text.presence
            article.page_start     = metadata.at_xpath('front/article-meta/fpage')&.text.presence
            article.page_end       = metadata.at_xpath('front/article-meta/lpage')&.text.presence
          end
        end
      end
    end
  end
end
