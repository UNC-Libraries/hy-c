# frozen_string_literal: true
module Tasks
  require 'tasks/migration_helper'
  module IngestHelper
    def attach_pdf_to_work(work, file_path, depositor, visibility)
      attach_file_set_to_work(work: work, file_path: file_path, user: depositor, visibility: visibility)
    end

    def attach_xml_to_work(work, file_path, depositor)
      attach_file_set_to_work(work: work, file_path: file_path, user: depositor, visibility: Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE)
    end


    def attach_file_set_to_work(work:, file_path:, user:, visibility:)
      file_set_params = { visibility: visibility }

      begin
        # Ensure the work is persisted before attaching a FileSet
        work.save! unless work.persisted?

        File.open(file_path) do |file|
          file_set = FileSet.create
          actor = Hyrax::Actors::FileSetActor.new(file_set, user)

          actor.create_metadata(file_set_params)
          actor.create_content(file)
          actor.attach_to_work(work, file_set_params)

          file_set.permissions_attributes = group_permissions(work.admin_set)
          file_set.save!
          file_set
        end
      rescue StandardError => e
        Rails.logger.error("Error attaching file_set for new work with #{work.identifier.first} and file_path: #{file_path}")
        Rails.logger.error [e.class.to_s, e.message, *e.backtrace].join($RS)
        nil
      end
    end

    def group_permissions(admin_set)
      @group_permissions ||= WorkUtilsHelper.get_permissions_attributes(admin_set.id)
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
  end
end
