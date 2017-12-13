module Hyrax::Workflow::AssignReviewerByAcademicDepartment

  def self.call(target:, **)
    reviewer = find_reviewer_for(department: target.academic_department)
    # This assigns database permissions, but does not grant permissions on the Fedora object.
    Hyrax::Workflow::PermissionGenerator.call(entity: target, agents: [reviewer],
                                              roles: ['approving'],
                                              workflow: Sipity::Workflow.find_by_name('one_step_mediated_deposit'))
  end

  def self.find_reviewer_for(department:)
    Sipity::Agent.where(proxy_for_id: department.to_s.downcase+'_reviewer',
                                proxy_for_type: 'Hyrax::Group').first_or_create
  end
end
