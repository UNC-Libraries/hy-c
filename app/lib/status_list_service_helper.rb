# [hyc-override] Overriding workflow permissions methods
Hyrax::Workflow::StatusListService.class_eval do
  private

  # update query params to find individual works that a user can access
  def query(actionable_roles)
    actionable_roles.reject!(&:blank?)
    entities = entities_for_user
    query_params = []

    if !actionable_roles.blank? && entities.blank?
      query_params << "({!terms f=actionable_workflow_roles_ssim}#{actionable_roles.join(',')})"
      query_params << @filter_condition
    elsif actionable_roles.blank? && !entities.blank?
      query_params << "((id:#{entities.join(' OR id:')}) AND #{@filter_condition})"
    elsif !actionable_roles.blank? && !entities.blank?
      query_params << "((({!terms f=actionable_workflow_roles_ssim}#{actionable_roles.join(',')})"
      query_params << @filter_condition + ")) OR ((id:#{entities.join(' OR id:')}) AND #{@filter_condition}))"
    else
      query_params << @filter_condition
    end

    query_params
  end

  # skip depositing role
  def roles_for_user
    Sipity::Workflow.all.flat_map do |wf|
      workflow_roles_for_user_and_workflow(wf).map do |wf_role|
        "#{wf.permission_template.source_id}-#{wf.name}-#{wf_role.role.name}" unless wf_role.role.name == 'depositing'
      end
    end
  end

  # add method for finding entities where user has approving access
  def entities_for_user
    entity_array = []
    approving_role = Sipity::Role.find_by(name: Hyrax::RoleRegistry::APPROVING)
    Hyrax::Workflow::PermissionQuery.scope_processing_agents_for(user: user).map do |agent|
      entities = agent.entity_specific_responsibilities.joins(:workflow_role).where('sipity_workflow_roles.role_id' => approving_role.id)
      unless entities.blank?
        entities.each do |entity|
          entity_array << "#{(Sipity::Entity.find(entity.entity_id).proxy_for_global_id).split('/')[-1]}"
        end
      end
    end
    entity_array
  end
end
