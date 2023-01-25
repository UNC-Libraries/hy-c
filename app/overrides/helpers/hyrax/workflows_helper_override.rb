# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/v3.4.2/app/helpers/hyrax/file_set_helper.rb
Hyrax::WorkflowsHelper.module_eval do
  def workflow_restriction?(object, ability: current_ability)
    return false if object.nil? # Yup, we may get nil, and there's no restriction on nil
    return object.workflow_restriction? if object.respond_to?(:workflow_restriction?)
    return false if ability.can?(:edit, object)
    # [hyc-override] permit access when user can read the object and has roles in the workflow.
    # This handles cases where objects are suppressed, but the workflow grants viewing for some.
    return false if ability.can?(:read, object) && object.respond_to?(:workflow) && object.workflow.actions.present?
    return object.suppressed? if object.respond_to?(:suppressed?)
    false
  end
end
