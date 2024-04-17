# frozen_string_literal: true
module Tasks
  require 'tasks/migration_helper'
  require 'tasks/ingest_helper'

  class SageNewArticleIngester < SageBaseArticleIngester
    attr_accessor :admin_set

    def process_package
      logger.error("Creating new Article with DOI: #{@jats_ingest_work.identifier}")
      # Create Article with metadata and save
      art_with_meta = article_with_metadata
      create_sipity_workflow(work: art_with_meta)
      # Add PDF file to Article (including FileSets)
      pdf_path = pdf_file_path

      pdf_file = attach_pdf_to_work(art_with_meta, pdf_path)
      pdf_file.update permissions_attributes: group_permissions(admin_set)

      # Add xml metadata file to Article
      xml_file = attach_xml_to_work(art_with_meta, @jats_ingest_work.xml_path)
      xml_file.update permissions_attributes: group_permissions(admin_set)
      art_with_meta.id
    end

    def article_with_metadata
      @logger.info("Creating Article from DOI: #{@jats_ingest_work.identifier}")
      art = Article.new
      art.admin_set = @admin_set
      populate_article_metadata(art)
      art.visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
      art.permissions_attributes = group_permissions(admin_set)
      art.save!
      # return the Article object
      art
    end
  end
end
