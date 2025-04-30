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
        article = new_article(metadata)
        populate_article_metadata(article, metadata)
        attach_pdf(article, metadata)
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
      set_basic_attributes(metadata, @depositor, article.visibility)
    end

    # WIP: =================== Focus Area
    def set_basic_attributes(metadata, depositor_onyen, visibility)
      if metadata.name == 'PubmedArticle'
        article.title = metadata.xpath('MedlineCitation/Article/ArticleTitle').text
        article.doi = metadata.xpath('PubmedData/ArticleIdList/ArticleId[@IdType="doi"]').text
        article.pmid = metadata.xpath('PubmedData/ArticleIdList/ArticleId[@IdType="pubmed"]').text
        article.pmcid = metadata.xpath('PubmedData/ArticleIdList/ArticleId[@IdType="pmc"]').text
        article.abstract = metadata.xpath('MedlineCitation/Article/Abstract/AbstractText').text
        article.authors = metadata.xpath('MedlineCitation/Article/AuthorList/Author').map do |author|
          "#{author.xpath('LastName').text}, #{author.xpath('ForeName').text}"
        end.join(', ')
      else
      end
    end
    # WIP: =================== Focus Area
end
end
