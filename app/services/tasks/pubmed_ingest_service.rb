# frozen_string_literal: true
module Tasks
  require 'tasks/ingest_helper'

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
          skipped_row = find_skipped_row_for_metadata(metadata)
          Rails.logger.info("[Ingest] Found skipped row: #{skipped_row.inspect}")
          article = new_article(metadata)
          article.identifier.each { |id| Rails.logger.info("[Ingest] Article identifier: #{id}") }
          Rails.logger.info("[Ingest] Created new article with ID #{article.id}")

          attach_pdf(article, metadata, skipped_row)

          Rails.logger.info("[Ingest] Successfully attached PDF for article #{article.id}")
          skipped_row['pdf_attached'] = 'Success'
          @attachment_results[:successfully_ingested] << skipped_row.to_h
        rescue => e
          Rails.logger.error("[Ingest] Error processing record ##{index + 1}: #{e.message}")
          Rails.logger.error(e.backtrace.join("\n"))
          article.destroy if article&.persisted?
          skipped_row['pdf_attached'] = e.message
          @attachment_results[:failed] << skipped_row.to_h
        end
      end

      Rails.logger.info('[Ingest] Ingestion complete')
      @attachment_results
    end

    def attach_pubmed_file(work_hash, file_path, depositor_onyen, visibility)
      model_class = work_hash[:work_type].constantize
      work = model_class.find(work_hash[:work_id])
      depositor = User.find_by(uid: depositor_onyen)
      file = attach_pdf_to_work(work, file_path, depositor, visibility)
      file.update(permissions_attributes: group_permissions(@admin_set))
      file
    end

    private

    def batch_retrieve_metadata
      Rails.logger.info("Starting metadata retrieval for #{@new_pubmed_works.size} records")

      works_with_pmids = @new_pubmed_works.select { |w| w['pmid'].present? }
      works_with_pmcids = @new_pubmed_works.select { |w| !works_with_pmids.include?(w) && w['pmcid'].present? }

      [works_with_pmids, works_with_pmcids].each do |works|
        db = (works == works_with_pmids) ? 'pubmed' : 'pmc'
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

    def new_article(metadata)
      Rails.logger.info('[Article] Initializing new article object')
      article = Article.new
      populate_article_metadata(article, metadata)
      article.visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
      article.permissions_attributes = group_permissions(@admin_set)
      article.save!
      Rails.logger.info("[Article] Article saved with ID #{article.id}")
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
      Rails.logger.info("[AttachPDF] PDF file attached to article #{article.id}")
      article
    end

    def populate_article_metadata(article, metadata)
      set_basic_attributes(metadata, @depositor.uid, article)
      set_journal_attributes(article, metadata)
      set_identifiers(article, metadata)
    end

    def set_basic_attributes(metadata, depositor_onyen, article)
      article.admin_set = @admin_set
      article.depositor = depositor_onyen
      article.resource_type = ['Article']
      article.creators_attributes = generate_authors(metadata)

      if metadata.name == 'PubmedArticle'
        article.title = [metadata.xpath('MedlineCitation/Article/ArticleTitle').text]
        article.abstract = [metadata.xpath('MedlineCitation/Article/Abstract/AbstractText').text]
        article.date_issued = get_date_issued(metadata)
        article.publisher = [metadata.at_xpath('MedlineCitation/MedlineJournalInfo/MedlineTA')&.text].compact.presence
        article.keyword = metadata.xpath('MedlineCitation/KeywordList/Keyword').map(&:text)
        article.funder = metadata.xpath('GrantList/Grant/Agency').map(&:text)
      elsif metadata.name == 'article'
        article.title = [metadata.xpath('front/article-meta/title-group/article-title').text]
        article.abstract = [metadata.xpath('front/article-meta/abstract').text]
        article.date_issued = get_date_issued(metadata)
        article.publisher = [metadata.at_xpath('front/journal-meta/publisher/publisher-name')&.text].compact.presence
        article.keyword = metadata.xpath('//kwd-group/kwd').map(&:text)
        article.funder = metadata.xpath('//funding-source/institution-wrap/institution').map(&:text)
      else
        raise StandardError, "Basic Attributes - Unknown metadata format: #{metadata.name}"
      end
    end

    def set_journal_attributes(article, metadata)
      if metadata.name == 'PubmedArticle'
        article.journal_title = metadata.at_xpath('MedlineCitation/Article/Journal/Title')&.text.presence
        article.journal_volume = metadata.at_xpath('MedlineCitation/Article/Journal/JournalIssue/Volume')&.text.presence
        article.journal_issue = metadata.at_xpath('MedlineCitation/Article/Journal/JournalIssue/Issue')&.text.presence
        start_page = metadata.at_xpath('MedlineCitation/Article/Pagination/StartPage')&.text
        end_page = metadata.at_xpath('MedlineCitation/Article/Pagination/EndPage')&.text

        article.page_start = start_page.presence
        article.page_end = end_page.presence
      elsif metadata.name == 'article'
        article.journal_title = metadata.at_xpath('front/journal-meta/journal-title-group/journal-title')&.text.presence
        article.journal_volume = metadata.at_xpath('front/article-meta/volume')&.text.presence
        article.journal_issue = metadata.at_xpath('front/article-meta/issue-id')&.text.presence
        start_page = metadata.at_xpath('front/article-meta/fpage')&.text
        end_page = metadata.at_xpath('front/article-meta/lpage')&.text

        article.page_start = start_page.presence
        article.page_end = end_page.presence
      else
        raise StandardError, "Journal Attributes - Unknown metadata format: #{metadata.name}"
      end
    end

    def set_identifiers(article, metadata)
      article.identifier = format_publication_identifiers(metadata)
      article.issn = if metadata.name == 'PubmedArticle'
                       [metadata.xpath('//ISSN[@IssnType="Electronic"]').text]
                 else
                   [metadata.xpath('//issn[@pub-type="epub"]').text]
                 end
    end

    def generate_authors(metadata)
      if metadata.name == 'PubmedArticle'
        metadata.xpath('MedlineCitation/Article/AuthorList/Author').map.with_index do |author, i|
          {
            'name' => [author.xpath('LastName').text, author.xpath('ForeName').text].join(', '),
            'orcid' => author.at_xpath('Identifier[@Source="orcid"]')&.text&.then { |id| "https://orcid.org/#{id}" } || '',
            'index' => i.to_s
          }
        end
      else
        metadata.xpath('front/article-meta/contrib-group/contrib[@contrib-type="author"]').map.with_index do |author, i|
          {
            'name' => [author.xpath('name/surname').text, author.xpath('name/given-names').text].join(', '),
            'orcid' => author.at_xpath('orcid')&.text&.then { |id| "https://orcid.org/#{id}" } || '',
            'index' => i.to_s
          }
        end
      end
    end

    def get_date_issued(metadata)
      pubdate = if metadata.name == 'PubmedArticle'
                  metadata.at_xpath('PubmedData/History/PubMedPubDate[@PubStatus="pubmed"]')
           else
             metadata.at_xpath('front/article-meta/pub-date[@pub-type="epub"]')
           end


      year = pubdate&.at_xpath('Year')&.text || pubdate&.at_xpath('year')&.text
      month = pubdate&.at_xpath('Month')&.text || pubdate&.at_xpath('month')&.text
      day = pubdate&.at_xpath('Day')&.text || pubdate&.at_xpath('day')&.text

      DateTime.new(year.to_i, (month || 1).to_i, (day || 1).to_i).strftime('%Y-%m-%d')
    end

    def format_publication_identifiers(metadata)
      if metadata.name == 'PubmedArticle'
        id_list = metadata.xpath('PubmedData/ArticleIdList')
        [
          (pmid = id_list.at_xpath('ArticleId[@IdType="pubmed"]')) ? "PMID: #{pmid.text}" : nil,
          (pmcid = id_list.at_xpath('ArticleId[@IdType="pmc"]')) ? "PMCID: #{pmcid.text}" : nil,
          (doi = id_list.at_xpath('ArticleId[@IdType="doi"]')) ? "DOI: https://dx.doi.org/#{doi.text}" : nil
        ].compact
      else
        article_meta = metadata.at_xpath('front/article-meta')
        [
          (pmid = article_meta.at_xpath('article-id[@pub-id-type="pmid"]')) ? "PMID: #{pmid.text}" : nil,
          (pmcid = article_meta.at_xpath('article-id[@pub-id-type="pmcid"]')) ? "PMCID: #{pmcid.text}" : nil,
          (doi = article_meta.at_xpath('article-id[@pub-id-type="doi"]')) ? "DOI: https://dx.doi.org/#{doi.text}" : nil
        ].compact
      end
    end

    def find_skipped_row_for_metadata(metadata)
      pmid, pmcid =
        if metadata.name == 'PubmedArticle'
          [
            metadata.at_xpath('PubmedData/ArticleIdList/ArticleId[@IdType="pubmed"]')&.text,
            metadata.at_xpath('PubmedData/ArticleIdList/ArticleId[@IdType="pmc"]')&.text
          ]
        else
          [
            metadata.at_xpath('.//article-id[@pub-id-type="pmid"]')&.text,
            metadata.at_xpath('.//article-id[@pub-id-type="pmcid"]')&.text
          ]
        end
      @new_pubmed_works.find { |row| row['pmid'] == pmid || row['pmcid'] == pmcid }
    end
  end
end
