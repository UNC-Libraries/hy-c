# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/hyrax-v3.6.0/app/services/hyrax/workflow/workflow_action_service.rb
Hyrax::Workflow::WorkflowActionService.class_eval do
  MAX_RETRIES = 3
  attr_writer :retry_delay_seconds

  private
    def retry_delay_seconds
      @retry_delay_seconds ||= 2
    end

    alias_method :original_handle_additional_sipity_workflow_action_processing, :handle_additional_sipity_workflow_action_processing

    # [hyc-override] Add retries to method for model mismatches to allow the system time to resolve them
    def handle_additional_sipity_workflow_action_processing(comment:)
      (1..MAX_RETRIES).each do |retry_num|
        begin
          return original_handle_additional_sipity_workflow_action_processing(comment: comment)
        rescue ActiveFedora::ModelMismatch => e
          if retry_num < MAX_RETRIES
            Rails.logger.warn("Failed to perform handle_additional_sipity_workflow_action_processing for #{subject.work.id}, try #{retry_num}: #{e.message}")
            sleep retry_delay_seconds
          else
            raise e
          end
        end
      end
    end
end
