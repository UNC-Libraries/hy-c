# frozen_string_literal: true
module Tasks
  require 'tasks/migration_helper'

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
      pdf_file.update permissions_attributes: group_permissions

      # Add xml metadata file to Article
      xml_file = attach_xml_to_work(art_with_meta, @jats_ingest_work.xml_path)
      xml_file.update permissions_attributes: group_permissions
      art_with_meta.id
    end

    def create_sipity_workflow(work:)
      # Create sipity record
      join = Sipity::Workflow.joins(:permission_template)
      workflow = join.where(permission_templates: { source_id: work.admin_set_id }, active: true)
      raise(ActiveRecord::RecordNotFound, "Could not find Sipity::Workflow with permissions template with source id #{work.admin_set_id}") unless workflow.present?

      workflow_state = Sipity::WorkflowState.where(workflow_id: workflow.first.id, name: 'deposited')
      raise(ActiveRecord::RecordNotFound, "Could not find Sipity::WorkflowState with workflow_id: #{workflow.first.id} and name: 'deposited'") unless workflow_state.present?

      Sipity::Entity.create!(proxy_for_global_id: work.to_global_id.to_s,
                             workflow: workflow.first,
                             workflow_state: workflow_state.first)
    end

    def article_with_metadata
      @logger.info("Creating Article from DOI: #{@jats_ingest_work.identifier}")
      art = Article.new
      art.admin_set = @admin_set
      populate_article_metadata(art)
      art.visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
      art.permissions_attributes = group_permissions
      art.save!
      # return the Article object
      art
    end

    def group_permissions
      @group_permissions ||= MigrationHelper.get_permissions_attributes(@admin_set.id)
    end
  end
end
