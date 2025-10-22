# frozen_string_literal: true
module Tasks
  require 'tasks/migration_helper'
  module IngestHelperUtils
    module IngestHelper
      def attach_pdf_to_work(work:, file_path:, depositor:, visibility:, filename: nil)
        LogUtilsHelper.double_log("Attaching PDF to work #{work.id} from path #{file_path}", :info, tag: 'AttachPDF')
        attach_file_set_to_work(work: work, file_path: file_path, user: depositor, visibility: visibility, filename: filename)
      end

      def attach_xml_to_work(work:, file_path:, depositor:, filename: nil)
        LogUtilsHelper.double_log("Attaching XML to work #{work.id} from path #{file_path}", :info, tag: 'AttachXML')
        attach_file_set_to_work(work: work,
                            file_path: file_path,
                            user: depositor,
                            visibility: Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE,
                            filename: filename)
      end

      def attach_pdf_to_work_with_file_path!(record:, file_path:, depositor_onyen:, filename: nil)
        work_id = record.dig('ids', 'work_id')
        raise ArgumentError, 'No article ID found to attach PDF' unless work_id.present?

        article   = Article.find(work_id)
        depositor = ::User.find_by(uid: depositor_onyen)
        raise 'No depositor found' unless depositor

        file_set = attach_pdf_to_work(work: article,
                              file_path: file_path,
                              depositor: depositor,
                              visibility: article.visibility,
                              filename: filename)
        file_set
      end

      def attach_file_set_to_work(work:, file_path:, user:, visibility:, filename:)
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

            display_filename = filename || File.basename(file_path)
            file_set.label = display_filename
            file_set.title = [display_filename]

            file_set.permissions_attributes = group_permissions(work.admin_set)
            file_set.save!
            file_set.update_index

            Rails.logger.info("Attached FileSet #{file_set.id} to #{work.id} as #{display_filename}")
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
        join = Sipity::Workflow.joins(:permission_template)
        workflow = join.where(permission_templates: { source_id: work.admin_set_id }, active: true)
        unless workflow.present?
          raise(ActiveRecord::RecordNotFound, "Could not find Sipity::Workflow with permissions template with source id #{work.admin_set_id}")
        end

        workflow_state = Sipity::WorkflowState.where(workflow_id: workflow.first.id, name: 'deposited')
        unless workflow_state.present?
          raise(ActiveRecord::RecordNotFound, "Could not find Sipity::WorkflowState with workflow_id: #{workflow.first.id} and name: 'deposited'")
        end

        Rails.logger.info("Creating Sipity::Entity for work #{work.id}")
        Sipity::Entity.create!(
          proxy_for_global_id: work.to_global_id.to_s,
          workflow: workflow.first,
          workflow_state: workflow_state.first
        )
      end

      # Ensures that a work has proper permissions and workflow setup, creating them if needed.
      # Forces pre-existing works into a specific workflow state (default: 'deposited').
      def sync_permissions_and_state!(work_id, depositor_uid, state: 'deposited')
        work = Article.find(work_id)
        entity = Sipity::Entity.find_by(proxy_for_global_id: work.to_global_id.to_s)

        create_sipity_workflow(work: work) if entity.nil?
        work.permissions_attributes = group_permissions(work.admin_set)
        work.save!

        force_workflow_state!(work, state: state)
        reindex_work!(work)
        work
      end

      # Forces a work into a specific workflow state, creating the Sipity::Entity if needed.
      def force_workflow_state!(work, state: 'deposited')
        raise ArgumentError, 'No work provided to enforce workflow state' if work.nil?
        entity = Sipity::Entity.find_by(proxy_for_global_id: work.to_global_id.to_s)
        if entity.nil?
          Rails.logger.warn "Sipity entity missing for #{work.id} when forcing workflow state."
          raise ActiveRecord::RecordNotFound, "Sipity entity not found for #{work.id}"
        end
        target_state = Sipity::WorkflowState.find_by!(workflow: entity.workflow, name: state)

        if entity.workflow_state != target_state
          Rails.logger.info "Updating workflow state for #{work.id} to #{state}"
          entity.update!(workflow_state: target_state)
        end
      rescue => e
        Rails.logger.error "Failed to enforce workflow state for #{work.id}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end

      def reindex_work!(work)
        work.reload
        work.update_index
      end

      def delete_full_text_pdfs(config:)
        full_text_dir = Pathname.new(config['full_text_dir'])
        if full_text_dir.exist? && full_text_dir.directory?
          FileUtils.rm_rf(full_text_dir.to_s)
          LogUtilsHelper.double_log("Deleted full text PDFs directory: #{full_text_dir}", :info, tag: 'cleanup')
        else
          LogUtilsHelper.double_log("Full text PDFs directory not found: #{full_text_dir}", :warn, tag: 'cleanup')
        end
      end
    end
  end
end
