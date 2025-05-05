# frozen_string_literal: true
module Tasks
  require 'tasks/ingest_helper'
  class PubmedIngestService
    include Tasks::IngestHelper

    def initialize(config)
      # Validate the config hash
      @config = config
      raise ArgumentError, 'Missing required config keys' unless config['admin_set'] && config['depositor_onyen'] && config['new_pubmed_works']

      @new_pubmed_works = config['new_pubmed_works']
      admin_set_title = config['admin_set']

      @admin_set = ::AdminSet.find_by(title: admin_set_title)
      raise ActiveRecord::RecordNotFound, "AdminSet not found with title: #{admin_set_title}" unless @admin_set

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
      admin_set = ::AdminSet.where(id: work_hash[:admin_set_id]).first
      file.update(permissions_attributes: group_permissions(admin_set))
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
      res = []
      # Ingest the retrieved metadata
      @retrieved_metadata.each do |metadata|
        begin
        article = new_article(metadata)
        populate_article_metadata(article, metadata)
        attach_pdf(article, metadata)
        res << article
        rescue => e
          Rails.logger.error("Error ingesting article: #{e.message}")
          Rails.logger.error(e.backtrace.join("\n"))
          # WIP: Refactoring for error handling, reporting
          res << { error: e.message }
      end
      res
    end

    def new_article(metadata)
      article = Article.new
      populate_article_metadata(article, metadata)
      article.visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
      article.permissions_attributes = group_permissions(@admin_set)
      article.save!
      article
    end

    def attach_pdf(article, metadata)
      create_sipity_workflow(work: article)
      pdf_file = attach_pdf_to_work(article, metadata['path'], @depositor, article.visibility)
      pdf_file.update(permissions_attributes: group_permissions(@admin_set))
      article
    end

    def populate_article_metadata(article, metadata)
      set_basic_attributes(metadata, @depositor, article)
    end

    # WIP: =================== Focus Area
    def set_basic_attributes(metadata, depositor_onyen, article)
      article.admin_set = @admin_set
      article.depositor = @config['depositor_onyen']
      article.resource_type = ['Article']
      if metadata.name == 'PubmedArticle'
        article.title = metadata.xpath('MedlineCitation/Article/ArticleTitle').text
        article.abstract = metadata.xpath('MedlineCitation/Article/Abstract/AbstractText').text
        article.date_issued = get_date_issued(metadata)
        # WIP: Generate Creator Hash Later
        # article.creators_attributes = publication['authors'].map.with_index { |author, index| [index, author_to_hash(author, index)] }.to_h
        # article.doi = metadata.xpath('PubmedData/ArticleIdList/ArticleId[@IdType="doi"]').text
        # article.pmid = metadata.xpath('PubmedData/ArticleIdList/ArticleId[@IdType="pubmed"]').text
        # article.pmcid = metadata.xpath('PubmedData/ArticleIdList/ArticleId[@IdType="pmc"]').text
      elsif metadata.name == 'article'
        article.title = metadata.xpath('front/article-meta/title-group/article-title').text
        article.abstract = metadata.xpath('front/article-meta/abstract').text
        article.date_issued = get_date_issued(metadata)
      else
        # Raise an error for unknown metadata formats
        raise StandardError, "Unknown metadata format: #{metadata.name}"
      end
    end
    # WIP: =================== Focus Area

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
end
end
