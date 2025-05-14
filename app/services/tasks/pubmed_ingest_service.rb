# frozen_string_literal: true
module Tasks
  require 'tasks/ingest_helper'
  class PubmedIngestService
    include Tasks::IngestHelper

    def initialize(config)
      # Validate the config hash
      raise ArgumentError, 'Missing required config keys' unless config['admin_set_title'] && config['depositor_onyen'] && config['attachment_results']

      @attachment_results = config['attachment_results'].symbolize_keys

      # Exclude the "Skipped: No CDR URL" rows from the attachment results
      @new_pubmed_works = @attachment_results[:skipped].select { |row| row['pdf_attached'] == 'Skipped: No CDR URL' }
      @attachment_results[:skipped] = @attachment_results[:skipped].reject { |row| row['pdf_attached'] == 'Skipped: No CDR URL' }

      @admin_set = ::AdminSet.where(title: config['admin_set_title'])&.first
      raise ActiveRecord::RecordNotFound, "AdminSet not found with title: #{config['admin_set_title']}" unless @admin_set

      @depositor = User.find_by(uid: config['depositor_onyen'])
      raise ActiveRecord::RecordNotFound, "User not found with onyen: #{config['depositor_onyen']}" unless @depositor

      @retrieved_metadata = []
    end
    def ingest_publications
      batch_retrieve_metadata
      # Ingest the retrieved metadata, returns a modified array of hashes
      Rails.logger.info("Starting ingestion of #{@retrieved_metadata.size} records")
      @retrieved_metadata.each_with_index do |metadata, index|
        begin
          # Retrieve the corresponding row from @new_pubmed_works to be updated
          skipped_row = find_skipped_row_for_metadata(metadata)
          article = new_article(metadata)
          attach_pdf(article, metadata, skipped_row)
          skipped_row['pdf_attached'] = 'Success'
          @attachment_results[:successfully_ingested] << skipped_row.to_h
        rescue => e
           Rails.logger.error(e.message)
           Rails.logger.error(e.backtrace.join("\n"))
          skipped_row['pdf_attached'] = e.message
          @attachment_results[:failed] << skipped_row.to_h
        end
      end
       # Use updated attachment_results for reporting
      Rails.logger.info("Ingestion complete")
      @attachment_results
    end

    def attach_pubmed_file(work_hash, file_path, depositor_onyen, visibility)
     # Create a work object using the provided work_hash
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
          # Include Tool Name and Email in API request
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
      @retrieved_metadata
      Rails.logger.info("Metadata retrieval complete")
    end

    def new_article(metadata)
      article = Article.new
      populate_article_metadata(article, metadata)
      article.visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
      article.permissions_attributes = group_permissions(@admin_set)
      article.save!
      article
    end

    def attach_pdf(article, metadata, skipped_row)
      create_sipity_workflow(work: article)
      pdf_file = attach_pdf_to_work(article, metadata['path'], @depositor, article.visibility)
      if pdf_file.nil?
        ids = [skipped_row['pmid'], skipped_row['pmcid']].compact.join(', ')
        raise StandardError, "File attachment error for identifiers: #{ids}"
      end
      pdf_file.update(permissions_attributes: group_permissions(@admin_set))
      article
    end

    def populate_article_metadata(article, metadata)
      set_basic_attributes(metadata, @depositor.uid, article)
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
        publisher = metadata.at_xpath('MedlineCitation/MedlineJournalInfo/MedlineTA')&.text
        article.publisher = [publisher].compact.presence
        article.keyword = metadata.xpath('MedlineCitation/KeywordList/Keyword').map(&:text)
        article.funder = metadata.xpath('GrantList/Grant/Agency').map(&:text)
      elsif metadata.name == 'article'
        article.title = [metadata.xpath('front/article-meta/title-group/article-title').text]
        article.abstract = [metadata.xpath('front/article-meta/abstract').text]
        article.date_issued = get_date_issued(metadata)
        publisher = metadata.at_xpath('front/journal-meta/publisher/publisher-name')&.text
        article.publisher = [publisher].compact.presence
        article.keyword = metadata.xpath('//kwd-group/kwd').map(&:text)
        article.funder = metadata.xpath('//funding-source/institution-wrap/institution').map(&:text)
      else
        # Raise an error for unknown metadata formats
        raise StandardError, "Basic Attributes - Unknown metadata format: #{metadata.name}"
      end
    end

    def set_identifiers(article, metadata)
      article.identifier = format_publication_identifiers(metadata)
      if metadata.name == 'PubmedArticle'
        article.issn = [metadata.xpath('//ISSN[@IssnType="Electronic"]').text]
      else
        article.issn = [metadata.xpath('//issn[@pub-type="epub"]').text]
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
      # Extract the date_issued from the metadata
      if metadata.name == 'PubmedArticle'
        pubdate = metadata.at_xpath('PubmedData/History/PubMedPubDate[@PubStatus="pubmed"]')
        year, month, day = pubdate&.at_xpath('Year')&.text, pubdate&.at_xpath('Month')&.text, pubdate&.at_xpath('Day')&.text
      else
        pubdate = metadata.at_xpath('front/article-meta/pub-date[@pub-type="epub"]')
        year, month, day = pubdate&.at_xpath('year')&.text, pubdate&.at_xpath('month')&.text, pubdate&.at_xpath('day')&.text
      end
      month = month.to_i.zero? ? 1 : month.to_i
      day = day.to_i.zero? ? 1 : day.to_i
      formatted = DateTime.new(year.to_i, month, day).strftime('%Y-%m-%d')
      formatted
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
          (pmid = article_meta.at_xpath('pub-id[@pub-id-type="pmid"]')) ? "PMID: #{pmid.text}" : nil,
          (pmcid = article_meta.at_xpath('pub-id[@pub-id-type="pmcid"]')) ? "PMCID: #{pmcid.text}" : nil,
          (doi = article_meta.at_xpath('pub-id[@pub-id-type="doi"]')) ? "DOI: https://dx.doi.org/#{doi.text}" : nil
        ].compact
      end
    end

    def find_skipped_row_for_metadata(metadata)
      if metadata.name == 'PubmedArticle'
        pmid = metadata.xpath('PubmedData/ArticleIdList/ArticleId[@IdType="pubmed"]').text
        pmcid = metadata.xpath('PubmedData/ArticleIdList/ArticleId[@IdType="pmc"]').text
      else
        pmid = metadata.xpath('front/article-meta/pub-id[@pub-id-type="pmid"]').text
        pmcid = "PMC#{metadata.xpath('front/article-meta/pub-id[@pub-id-type="pmc"]').text}"
      end
      # Select a row from the attachment results based on an identifier extracted from the metadata
      match = @new_pubmed_works.find { |row| row['pmid'] == pmid || row['pmcid'] == pmcid }
      match
    end
  end
end
