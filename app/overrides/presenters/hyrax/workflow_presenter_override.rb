# frozen_string_literal: true
# [hyc-override] https://github.com/samvera/hyrax/tree/hyrax-v4.0.0/app/presenters/hyrax/workflow_presenter.rb
Hyrax::WorkflowPresenter.class_eval do
  def actions
    # [hyc-override] Hide panel from non-admins if the workflow action is to withdraw/delete the work
    return [] unless sipity_entity && current_ability && (current_ability.current_user.admin? || state != 'pending_deletion')
    actions = Hyrax::Workflow::PermissionQuery.scope_permitted_workflow_actions_available_for_current_state(entity: sipity_entity, user: current_ability.current_user)
    actions.map { |action| [action.name, action_label(action)] }
  end

  # [hyc-override] Add check to display message to MFA workflow depositor
  def is_mfa_in_review?
    return false unless sipity_entity

    sipity_entity&.workflow_name == 'art_mfa_deposit' && state == 'pending_review'
  end

  # [hyc-override] Add check to display attach works button to MFA workflow depositor
  def is_mfa?
    return false unless sipity_entity

    sipity_entity&.workflow_name == 'art_mfa_deposit'
  end

  # [hyc-override] Add permission checks to hide withdrawn files
  def in_workflow_state?(test_states = [])
    return false unless state && !test_states.blank?

    test_state_regex = test_states.join('|').gsub(/\s+/, '.+')
    !/#{test_state_regex}/.match(state).nil?
  end
end
