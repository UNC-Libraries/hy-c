# frozen_string_literal: true
module Tasks
  require 'tasks/migration_helper'
  module IngestHelper
    def attach_pdf_to_work(work, file_path, depositor, visibility)
      LogUtilsHelper.double_log("Attaching PDF to work #{work.id} from path #{file_path}", :info, tag: 'AttachPDF')
      attach_file_set_to_work(work: work, file_path: file_path, user: depositor, visibility: visibility)
    end

    def attach_xml_to_work(work, file_path, depositor)
      LogUtilsHelper.double_log("Attaching XML to work #{work.id} from path #{file_path}", :info, tag: 'AttachXML')
      attach_file_set_to_work(work: work, file_path: file_path, user: depositor, visibility: Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE)
    end

    def attach_pdf_to_work_with_binary!(record, pdf_binary, filename)
      work_id = record.dig('ids', 'work_id')
      raise ArgumentError, 'No article ID found to attach PDF' unless work_id.present?

      article   = Article.find(work_id)
      depositor = ::User.find_by(uid: 'admin')
      raise 'No depositor found' unless depositor

      file_path = File.join(@full_text_path, filename)
      File.binwrite(file_path, pdf_binary)
      FileUtils.chmod(0o644, file_path)

      file_set = attach_pdf_to_work(article, file_path, depositor, article.visibility)

      [file_set, File.basename(file_path)]
    end

    def attach_file_set_to_work(work:, file_path:, user:, visibility:)
      file_set_params = { visibility: visibility }

      begin
        # LogUtilsHelper.double_log("Ensuring work #{work.id} is persisted", :info, tag: 'FileSetAttach')
        Rails.logger.debug("Ensuring work #{work.id} is persisted")
        work.save! unless work.persisted?

        File.open(file_path) do |file|
          # LogUtilsHelper.double_log("Creating FileSet and Actor for user #{user.uid}", :info, tag: 'FileSetAttach')
          Rails.logger.debug("Creating FileSet and Actor for user #{user.uid}")
          file_set = FileSet.create
          actor = Hyrax::Actors::FileSetActor.new(file_set, user)

          # LogUtilsHelper.double_log("Calling create_metadata for FileSet #{file_set.id}", :info, tag: 'FileSetAttach')
          Rails.logger.debug("Calling create_metadata for FileSet #{file_set.id}")
          actor.create_metadata(file_set_params)

          # LogUtilsHelper.double_log("Calling create_content for FileSet #{file_set.id}", :info, tag: 'FileSetAttach')
          attach_file_content(file_set: file_set, user: user, file: file)
          # LogUtilsHelper.double_log("Attaching FileSet #{file_set.id} to work #{work.id}", :info, tag: 'FileSetAttach')
          Rails.logger.debug("Attaching FileSet #{file_set.id} to work #{work.id}")
          actor.attach_to_work(work, file_set_params)

          file_set.permissions_attributes = group_permissions(work.admin_set)
          file_set.save!

          # LogUtilsHelper.double_log("Successfully attached FileSet #{file_set.id} to work #{work.id}", :info, tag: 'FileSetAttach')
          Rails.logger.info("Successfully attached FileSet #{file_set.id} to work #{work.id}")
          file_set
        end
      rescue StandardError => e
        LogUtilsHelper.double_log("Error attaching FileSet to work #{work.id}: #{e.message}", :error, tag: 'FileSetAttach')
        Rails.logger.error("Error attaching file_set for new work with #{work.identifier.first} and file_path: #{file_path}")
        Rails.logger.error [e.class.to_s, e.message, *e.backtrace].join($RS)
        nil
      end
    end

    def group_permissions(admin_set)
      @group_permissions ||= WorkUtilsHelper.get_permissions_attributes(admin_set.id)
    end

    def attach_file_content(file_set:, user:, file:)
      job = ::JobIoWrapper.create!(
        user: user,
        file_set_id: file_set.id,
        path: File.expand_path(file.path),
        relation: 'original_file',
        mime_type: 'application/pdf',
        original_name: File.basename(file.path)
      )
      IngestJob.perform_later(job)
      LogUtilsHelper.double_log("Inspect Original File for FileSet #{file_set.original_file.inspect}", :info, tag: 'FileSetAttach')
      CreateDerivativesJob.perform_later(file_set, file_set.original_file.id) if file_set.original_file.present?
    end

    def create_sipity_workflow(work:)
      LogUtilsHelper.double_log("Creating Sipity workflow for work #{work.id}", :info, tag: 'Sipity')

      join = Sipity::Workflow.joins(:permission_template)
      workflow = join.where(permission_templates: { source_id: work.admin_set_id }, active: true)
      unless workflow.present?
        raise(ActiveRecord::RecordNotFound, "Could not find Sipity::Workflow with permissions template with source id #{work.admin_set_id}")
      end

      workflow_state = Sipity::WorkflowState.where(workflow_id: workflow.first.id, name: 'deposited')
      unless workflow_state.present?
        raise(ActiveRecord::RecordNotFound, "Could not find Sipity::WorkflowState with workflow_id: #{workflow.first.id} and name: 'deposited'")
      end

      LogUtilsHelper.double_log("Creating Sipity::Entity for work #{work.id}", :info, tag: 'Sipity')
      Sipity::Entity.create!(
        proxy_for_global_id: work.to_global_id.to_s,
        workflow: workflow.first,
        workflow_state: workflow_state.first
      )
    end
  end
end
