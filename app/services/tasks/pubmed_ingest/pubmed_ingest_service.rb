# frozen_string_literal: true
module Tasks
  require 'tasks/ingest_helper'
  module PubmedIngest

    class PubmedIngestService
      include Tasks::IngestHelper

      def initialize(config)
        raise ArgumentError, 'Missing required config keys' unless config['admin_set_title'] && config['depositor_onyen'] && config['attachment_results']

        @attachment_results = config['attachment_results'].symbolize_keys
        @new_pubmed_works = @attachment_results[:skipped].select { |row| row['pdf_attached'] == 'Skipped: No CDR URL' }
        @attachment_results[:skipped] -= @new_pubmed_works

        @admin_set = ::AdminSet.where(title: config['admin_set_title'])&.first
        raise ActiveRecord::RecordNotFound, "AdminSet not found with title: #{config['admin_set_title']}" unless @admin_set

        @depositor = User.find_by(uid: config['depositor_onyen'])
        raise ActiveRecord::RecordNotFound, "User not found with onyen: #{config['depositor_onyen']}" unless @depositor

        @retrieved_metadata = []
      end

      def ingest_publications
        batch_retrieve_metadata
        Rails.logger.info("[Ingest] Starting ingestion of #{@retrieved_metadata.size} records")
        @retrieved_metadata.each_with_index do |metadata, index|
          Rails.logger.info("[Ingest] Processing record ##{index + 1}")
          begin
            builder = attribute_builder(metadata)
            skipped_row = builder.find_skipped_row(metadata, @new_pubmed_works)
            # skipped_row = is_pubmed?(metadata) ? find_skipped_row_for_pubmed_article(metadata) : find_skipped_row_for_pmc_article(metadata)
            # skipped_row = find_skipped_row_for_metadata(metadata)
            Rails.logger.info("[Ingest] Found skipped row: #{skipped_row.inspect}")
            article = new_article(metadata, builder)
            article.save!
            article.identifier.each { |id| Rails.logger.info("[Ingest] Article identifier: #{id}") }
            Rails.logger.info("[Ingest] Created new article with ID #{article.id}")
            attach_pdf(article, metadata, skipped_row)
            article.save!
            Rails.logger.info("[Ingest] Successfully attached PDF for article #{article.id}")
            skipped_row['pdf_attached'] = 'Success'
            skipped_row['article'] = article
            @attachment_results[:successfully_ingested] << skipped_row.to_h
          rescue => e
            doi = skipped_row&.[]('doi') || 'N/A'
            pmid = skipped_row&.[]('pmid') || 'N/A'
            pmcid = skipped_row&.[]('pmcid') || 'N/A'
            Rails.logger.error("[Ingest] Error processing record: DOI: #{doi}, PMID: #{pmid}, PMCID: #{pmcid}, Index: #{index}, Error: #{e.message}")
            Rails.logger.error("Backtrace: #{e.backtrace.join("\n")}")
            article.destroy if article&.persisted?
            skipped_row['pdf_attached'] = e.message
            @attachment_results[:failed] << skipped_row.to_h
          end
        end

        Rails.logger.info('[Ingest] Ingest complete')
        @attachment_results
      end

      def attach_pubmed_file(work_hash, file_path, depositor_onyen, visibility)
        model_class = work_hash[:work_type].constantize
        work = model_class.find(work_hash[:work_id])
        file = attach_pdf_to_work(work, file_path, @depositor, visibility)
        file.update(permissions_attributes: group_permissions(@admin_set))
        file
      end

      private

      def batch_retrieve_metadata
        Rails.logger.info("Starting metadata retrieval for #{@new_pubmed_works.size} records")

        works_with_pmids = @new_pubmed_works.select { |w| w['pmid'].present? }
        works_with_pmcids = @new_pubmed_works.select { |w| !w['pmid'].present?  && w['pmcid'].present? }

        [works_with_pmids, works_with_pmcids].each do |works|
          db = (works.equal?(works_with_pmids)) ? 'pubmed' : 'pmc'
          works.each_slice(200) do |batch|
            ids = batch.map { |w| w['pmid'] || w['pmcid'].sub(/^PMC/, '') }
            request_url = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=#{db}&id=#{ids.join(',')}&retmode=xml&tool=CDR&email=cdr@unc.edu"
            res = HTTParty.get(request_url)

            if res.code != 200
              Rails.logger.error("Failed to fetch metadata for #{ids.join(', ')}: #{res.code} - #{res.message}")
              next
            end

            xml_doc = Nokogiri::XML(res.body)
            current_arr = xml_doc.xpath(db == 'pubmed' ? '//PubmedArticle' : '//article')
            @retrieved_metadata += current_arr
          end
        end

        Rails.logger.info('Metadata retrieval complete')
        @retrieved_metadata
      end

      def new_article(metadata, builder)
        Rails.logger.info('[Article] Initializing new article object')
        article = Article.new
        article.visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
        article = populate_article_metadata(article, metadata, builder)
        article
      end

      def attach_pdf(article, metadata, skipped_row)
        Rails.logger.info("[AttachPDF] Attaching PDF for article #{article.id}")
        create_sipity_workflow(work: article)
        pdf_file = attach_pdf_to_work(article, metadata['path'], @depositor, article.visibility)

        if pdf_file.nil?
          ids = [skipped_row['pmid'], skipped_row['pmcid']].compact.join(', ')
          Rails.logger.error("[AttachPDF] ERROR: No PDF file was attached for: #{ids}")
          raise StandardError, "File attachment error for identifiers: #{ids}"
        end

        pdf_file.update(permissions_attributes: group_permissions(@admin_set))
      end

      def populate_article_metadata(article, metadata, builder)
        set_basic_attributes(metadata, @depositor.uid, article, builder)
        set_journal_attributes(article, metadata)
        set_rights_and_types(article, metadata)
        set_identifiers(article, metadata, builder)
        article
      end

      def set_basic_attributes(metadata, depositor_onyen, article, builder)
        article.admin_set = @admin_set
        article.depositor = depositor_onyen
        article.resource_type = ['Article']
        article.creators_attributes = generate_authors(metadata, builder)

        if is_pubmed?(metadata)
          article.title = [metadata.xpath('MedlineCitation/Article/ArticleTitle').text]
          article.abstract = [metadata.xpath('MedlineCitation/Article/Abstract/AbstractText').text]
          article.date_issued = builder.get_date_issued(metadata)
          # No explicit publisher in PubmedArticle XML
          article.publisher = []
          article.keyword = metadata.xpath('MedlineCitation/KeywordList/Keyword').map(&:text)
          article.funder = metadata.xpath('MedlineCitation/Article/GrantList/Grant/Agency').map(&:text)
        elsif metadata.name == 'article'
          article.title = [metadata.xpath('front/article-meta/title-group/article-title').text]
          article.abstract = [metadata.xpath('front/article-meta/abstract').text]
          article.date_issued = builder.get_date_issued(metadata)
          article.publisher = [metadata.at_xpath('front/journal-meta/publisher/publisher-name')&.text].compact.presence
          article.keyword = metadata.xpath('//kwd-group/kwd').map(&:text)
          article.funder = metadata.xpath('//funding-source/institution-wrap/institution').map(&:text)
        else
          raise StandardError, "Basic Attributes - Unknown metadata format: #{metadata.name}"
        end
      end

      def set_rights_and_types(article, metadata)
        rights_statement = 'http://rightsstatements.org/vocab/InC/1.0/'
        article.rights_statement = rights_statement
        article.rights_statement_label = CdrRightsStatementsService.label(rights_statement)
        article.dcmi_type = ['http://purl.org/dc/dcmitype/Text']
      end

      def set_journal_attributes(article, metadata)
        if is_pubmed?(metadata)
          article.journal_title = metadata.at_xpath('MedlineCitation/Article/Journal/Title')&.text
          article.journal_volume = metadata.at_xpath('MedlineCitation/Article/Journal/JournalIssue/Volume')&.text.presence
          article.journal_issue = metadata.at_xpath('MedlineCitation/Article/Journal/JournalIssue/Issue')&.text.presence
          article.page_start = metadata.at_xpath('MedlineCitation/Article/Pagination/StartPage')&.text.presence
          article.page_end   = metadata.at_xpath('MedlineCitation/Article/Pagination/EndPage')&.text.presence
        elsif metadata.name == 'article'
          article.journal_title = metadata.at_xpath('front/journal-meta/journal-title-group/journal-title')&.text.presence
          article.journal_volume = metadata.at_xpath('front/article-meta/volume')&.text.presence
          article.journal_issue = metadata.at_xpath('front/article-meta/issue-id')&.text.presence
          article.page_start = metadata.at_xpath('front/article-meta/fpage')&.text.presence
          article.page_end   = metadata.at_xpath('front/article-meta/lpage')&.text.presence
        end
      end

      def set_identifiers(article, metadata, builder)
        article.identifier = builder.format_publication_identifiers(metadata)
        article.issn = if is_pubmed?(metadata)
                         [metadata.xpath('MedlineCitation/Article/Journal/ISSN[@IssnType="Electronic"]').text]
                  else
                    [metadata.xpath('front/journal-meta/issn[@pub-type="epub"]').text]
                  end
      end

      def generate_authors(metadata, builder)
        if is_pubmed?(metadata)
          metadata.xpath('MedlineCitation/Article/AuthorList/Author').map.with_index do |author, i|
            res = {
              'name' => [author.xpath('LastName').text, author.xpath('ForeName').text].join(', '),
              'orcid' => author.at_xpath('Identifier[@Source="ORCID"]')&.text&.then { |id| "https://orcid.org/#{id}" } || '',
              'index' => i.to_s
            }
            builder.retrieve_author_affiliations(res, author, metadata.name)
            res
          end
        else
          metadata.xpath('front/article-meta/contrib-group/contrib[@contrib-type="author"]').map.with_index do |author, i|
            res = {
              'name' => [author.xpath('name/surname').text, author.xpath('name/given-names').text].join(', '),
              'orcid' => author.at_xpath('contrib-id[@contrib-id-type="orcid"]')&.text.to_s || '',
              'index' => i.to_s
            }
            # Include affiliations for each author if available
            builder.retrieve_author_affiliations(res, author, metadata.name)
            res
          end
        end
      end

      def is_pubmed?(metadata)
        metadata.name == 'PubmedArticle'
      end

      def attribute_builder(metadata)
        is_pubmed?(metadata) ? PubmedAttributeBuilder.new : PmcAttributeBuilder.new
      end
    end
  end
end
