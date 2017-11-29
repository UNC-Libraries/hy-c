module Hyrax::Workflow::AssignReviewerByAcademicDepartment

  def self.call(target:, **)
    reviewer = find_reviewer_for(department: target.academic_department)
    # This assigns database permissions, but does not grant permissions on the Fedora object.
    Hyrax::Workflow::PermissionGenerator.call(entity: target, agents: [reviewer],
                                              roles: ['approving'],
                                              workflow: Sipity::Workflow.find_by_name('one_step_mediated_deposit'))
  end

  def self.find_reviewer_for(department:)
    agent = Sipity::Agent.where(proxy_for_id: Role.find_by_name(department.to_s.downcase+'_reviewer').id,
                                proxy_for_type: 'Role').first
    if agent.nil?
      agent = Sipity::Agent.create(proxy_for: Role.find_by_name(department.to_s.downcase+'_reviewer'))
    end
    agent
  end
end
