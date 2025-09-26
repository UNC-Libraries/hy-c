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

    def attach_pdf_to_work_with_file_path!(record, file_path, depositor_onyen)
      work_id = record.dig('ids', 'work_id')
      raise ArgumentError, 'No article ID found to attach PDF' unless work_id.present?

      article   = Article.find(work_id)
      depositor = ::User.find_by(uid: depositor_onyen)
      raise 'No depositor found' unless depositor

      file_set = attach_pdf_to_work(article, file_path, depositor, article.visibility)
      file_set
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

          Rails.logger.debug("Attaching FileSet #{file_set.id} to work #{work.id}")
          actor.attach_to_work(work, file_set_params)

          Rails.logger.debug("Calling create_content for FileSet #{file_set.id} with file #{file.path}")
          actor.create_content(file)

          file_set.permissions_attributes = group_permissions(work.admin_set)
          file_set.save!

          Rails.logger.info("Successfully attached FileSet #{file_set.id} to work #{work.id}")
          file_set.label = File.basename(file_path)
          file_set.title = [File.basename(file_path)]
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

    # Creates a Sipity::Entity for a work and links it to an *existing* workflow/state.
    #
    # Use this when you just need to register a work in the workflow system
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


    # Ensures that a work has proper permissions and workflow setup, creating them if needed.
    #
    # Uses the Hyrax actor stack to "replay" the work creation process for an existing work.
    # This reapplies depositor permissions, workflow participants, and ensures the Sipity
    # entity + workflow state are present.
    def ensure_work_permissions!(work_id)
      begin
        return if work_id.blank?

        work = Article.find(work_id)
        entity = Sipity::Entity.find_by(proxy_for_global_id: work.to_global_id.to_s)

        if entity.nil?
          Rails.logger.info "No Sipity entity found for #{work.id}; applying workflow/permissions"
          user = User.find_by(uid: @config['depositor_onyen'])
          env  = Hyrax::Actors::Environment.new(work, Ability.new(user), {})
          Hyrax::CurationConcern.actor.create(env)
        end

        work.reload
        work.update_index
      rescue => e
        Rails.logger.error "Error ensuring permissions for work #{work_id}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end
  end
end
