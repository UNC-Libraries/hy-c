# frozen_string_literal: true
module Tasks
  require 'tasks/migration_helper'
  module IngestHelper
    def attach_pdf_to_work(work, file_path, depositor, visibility)
      LogUtilsHelper.double_log("Attaching PDF to work #{work.id} from path #{file_path}", :info, tag: 'AttachPDF')
      attach_file_set_to_work_with_logging(work: work, file_path: file_path, user: depositor, visibility: visibility)
    end

    def attach_xml_to_work(work, file_path, depositor)
      LogUtilsHelper.double_log("Attaching XML to work #{work.id} from path #{file_path}", :info, tag: 'AttachXML')
      attach_file_set_to_work_with_logging(work: work, file_path: file_path, user: depositor, visibility: Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE)
    end

    def attach_file_set_to_work_with_logging(work:, file_path:, user:, visibility:)
      file_set_params = { visibility: visibility }

      begin
        LogUtilsHelper.double_log("Ensuring work #{work.id} is persisted", :info, tag: 'FileSetAttach')
        work.save! unless work.persisted?

        File.open(file_path) do |file|
          LogUtilsHelper.double_log("Creating FileSet and Actor for user #{user.uid}", :info, tag: 'FileSetAttach')
          file_set = FileSet.create
          actor = Hyrax::Actors::FileSetActor.new(file_set, user)

          LogUtilsHelper.double_log("Calling create_metadata for FileSet #{file_set.id}", :info, tag: 'FileSetAttach')
          actor.create_metadata(file_set_params)

          LogUtilsHelper.double_log("Calling create_content for FileSet #{file_set.id}", :info, tag: 'FileSetAttach')
          actor.create_content(file)

          LogUtilsHelper.double_log("Attaching FileSet #{file_set.id} to work #{work.id}", :info, tag: 'FileSetAttach')
          actor.attach_to_work(work, file_set_params)

          file_set.permissions_attributes = group_permissions(work.admin_set)
          LogUtilsHelper.double_log("Saving FileSet #{file_set.id} with permissions", :info, tag: 'FileSetAttach')
          file_set.save!

          LogUtilsHelper.double_log("Successfully attached FileSet #{file_set.id} to work #{work.id}", :info, tag: 'FileSetAttach')
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