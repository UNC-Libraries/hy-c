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

    def attach_pubmed_file(work_hash, file_path, depositor_onyen, visibility)
      # Create a work object using the provided work_hash
      model_class = work_hash[:work_type].constantize
      work = model_class.find(work_hash[:work_id])
      depositor =  User.find_by(uid: depositor_onyen)
      file = attach_pdf_to_work(work, file_path, depositor, visibility)
      file.update(permissions_attributes: group_permissions(@admin_set))
      file
    end

    def batch_retrieve_metadata
      # Prep for retrieving metadata from different endpoints
      works_with_pmids = @new_pubmed_works.select { |work_hash| work_hash['pmid'].present? }
      works_with_pmcids = @new_pubmed_works.select { |work_hash| works_with_pmids.exclude?(work_hash) && work_hash['pmcid'].present? }

      [works_with_pmids, works_with_pmcids].each do |works|
        works.each_slice(200) do |batch|
          ids = batch.map { |work| work['pmid'] || work['pmcid'].sub(/^PMC/, '') } # Remove "PMC" prefix if present
          # Include Tool Name and Email in API request
          request_url = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=#{works == works_with_pmids ? 'pubmed' : 'pmc'}&id=#{ids.join(',')}&retmode=xml&tool=CDR&email=cdr@unc.edu"
          res = HTTParty.get(request_url)
          xml_doc = Nokogiri::XML(res.body)
          # WIP: Remove Later
          if res.code != 200
            Rails.logger.error("Failed to fetch metadata for #{ids.join(', ')}: #{res.code} - #{res.message}")
            next
          end
          current_arr = xml_doc.xpath(works == works_with_pmids ? '//PubmedArticle' : '//article')
          @retrieved_metadata += current_arr
        end
      end
      @retrieved_metadata
    end

    def ingest_publications
      # Ingest the retrieved metadata, returns a modified array of hashes
      @retrieved_metadata.each do |metadata|
        begin
         # Retrieve the corresponding row from @new_pubmed_works to be updated
         skipped_row = find_skipped_row_for_metadata(metadata)
         article = new_article(metadata)
         populate_article_metadata(article, metadata)
         attach_pdf(article, metadata, skipped_row)
         skipped_row['pdf_attached'] = 'Success'
         @attachment_results[:successfully_ingested] << skipped_row.to_h
        rescue => e
          Rails.logger.error(e.message)
          Rails.logger.error(e.backtrace.join("\n"))
          # WIP: Refactoring for error handling, reporting
          skipped_row['pdf_attached'] = e.message
          @attachment_results[:failed] << skipped_row.to_h
      end
      # Use updated attachment_results for reporting
      @attachment_results
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
        identifiers = []
        identifiers << "PMID: #{skipped_row['pmid']}" if skipped_row['pmid'].present?
        identifiers << "PMCID: #{skipped_row['pmcid']}" if skipped_row['pmcid'].present?
        raise StandardError, "File attachment error for new work with the following identifiers: #{identifiers.join(', ')}"
      end
      pdf_file.update(permissions_attributes: group_permissions(@admin_set))
      article
    end

    def populate_article_metadata(article, metadata)
      set_basic_attributes(metadata, @depositor, article)
    end

    def set_basic_attributes(metadata, depositor_onyen, article)
      article.admin_set = @admin_set
      article.depositor = @config['depositor_onyen']
      article.resource_type = ['Article']
      if metadata.name == 'PubmedArticle'
        article.title = metadata.xpath('MedlineCitation/Article/ArticleTitle').text
        article.abstract = metadata.xpath('MedlineCitation/Article/Abstract/AbstractText').text
        article.date_issued = get_date_issued(metadata)
        publisher = metadata.at_xpath('MedlineCitation/MedlineJournalInfo/MedlineTA')&.text
        article.publisher = [publisher].compact.presence
        keywords = metadata.xpath('MedlineCitation/KeywordList/Keyword').map(&:text)
        article.keyword = keywords if keywords.any?
      elsif metadata.name == 'article'
        article.title = metadata.xpath('front/article-meta/title-group/article-title').text
        article.abstract = metadata.xpath('front/article-meta/abstract').text
        article.date_issued = get_date_issued(metadata)
        publisher = metadata.at_xpath('front/journal-meta/publisher/publisher-name')&.text
        article.publisher = [publisher].compact.presence
      else
        # Raise an error for unknown metadata formats
        raise StandardError, "Unknown metadata format: #{metadata.name}"
      end
    end

    def get_date_issued(metadata)
      # Extract the date_issued from the metadata
      if metadata.name == 'PubmedArticle'
        pubmed_pubdate = metadata.at_xpath('PubmedData/History/PubMedPubDate[@PubStatus="pubmed"]')
        year = pubmed_pubdate.at_xpath('Year')&.text
        month = pubmed_pubdate.at_xpath('Month')&.text
        day = pubmed_pubdate.at_xpath('Day')&.text
      elsif metadata.name == 'article'
        #  Use the electronic publication date if available, otherwise use the first available publication date
        metadata_publication_date = metadata.at_xpath('front/article-meta/pub-date[@pub-type="epub"]') || nil
        if metadata_publication_date
          year = metadata_publication_date.at_xpath('year')&.text
          month = metadata_publication_date.at_xpath('month')&.text
          day = metadata_publication_date.at_xpath('day')&.text
        else
         # Raise an error if no publication date is found
         raise StandardError, "No publication date found in metadata for #{metadata.name}."
        end
      end
      # Provide defaults if day or month is missing
      month = month.zero? ? 1 : month
      day = day.zero? ? 1 : day
      # Format the date as YYYY-MM-DD
      DateTime.new(year.to_i, month.to_i, day.to_i).strftime('%Y-%m-%d')
    end

    def find_skipped_row_for_metadata(metadata)
      if metadata.name == 'PubmedArticle'
        pmid = metadata.xpath('PubmedData/ArticleIdList/ArticleId[@IdType="pubmed"]').text
        pmcid = metadata.xpath('PubmedData/ArticleIdList/ArticleId[@IdType="pmc"]').text
      elsif metadata.name == 'article'
        pmid = metadata.xpath('front/article-meta/pub-id[@pub-id-type="pmid"]').text
        pmcid = "PMC#{metadata.xpath('front/article-meta/pub-id[@pub-id-type="pmc"]').text}"
      end
        # Select a row from the attachment results based on an identifier extracted from the metadata
        @new_pubmed_works.find { |row| row['pmid'] == pmid || row['pmcid'] == pmcid }
    end
end
end
end
