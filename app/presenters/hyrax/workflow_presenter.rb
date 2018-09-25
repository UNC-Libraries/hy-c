# [hyc-override]
module Hyrax
  class WorkflowPresenter
    include ActionView::Helpers::TagHelper

    def initialize(solr_document, current_ability)
      @solr_document = solr_document
      @current_ability = current_ability
    end

    attr_reader :solr_document, :current_ability

    def state
      sipity_entity&.workflow_state_name
    end

    def state_label
      return unless state
      I18n.t("hyrax.workflow.state.#{state}", default: state.humanize)
    end

    # Returns an array of tuples (key, label) appropriate for a radio group
    def actions
      return [] unless sipity_entity && current_ability
      actions = Hyrax::Workflow::PermissionQuery.scope_permitted_workflow_actions_available_for_current_state(entity: sipity_entity, user: current_ability.current_user)
      actions.map { |action| [action.name, action_label(action)] }
    end

    def comments
      return [] unless sipity_entity
      sipity_entity.comments
    end

    def badge
      return unless state
      content_tag(:span, state_label, class: "state state-#{state} label label-primary")
    end

    # [hyc-override] Add check to display message to MFA workflow depositor
    def is_mfa_in_review?
      return false unless sipity_entity
      sipity_entity&.workflow_name == 'art_mfa_deposit' && state == 'pending_review'
    end

    # [hyc-override] Add permission checks to hide withdrawn files
    def in_workflow_state?(test_states = [])
      return false unless state && !test_states.blank?

      test_state_regex = test_states.join('|').gsub(/\s+/, '.+')
      !/#{test_state_regex}/.match(state).nil?
    end

    private

    def action_label(action)
      I18n.t("hyrax.workflow.#{action.workflow.name}.#{action.name}", default: action.name.titleize)
    end

    def sipity_entity
      PowerConverter.convert(solr_document, to: :sipity_entity)
    rescue PowerConverter::ConversionError
      nil
    end
  end
end
