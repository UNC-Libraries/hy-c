module Hyrax::Workflow::AssignReviewerByAcademicDepartment

  def self.call(target:, **)
    reviewer = find_reviewer_for(department: target.academic_department)
    # This assigns database permissions, but does not grant permissions on the Fedora object.
    Hyrax::Workflow::PermissionGenerator.call(entity: target, agents: [Sipity::Agent.find_by_proxy_for_id('history_reviewer')], roles: ['managing'],
                                              workflow: Sipity::Workflow.find_by_name('one_step_mediated_deposit'))
  end

  def self.find_reviewer_for(department:)
    ReviewersService.label(department)
  end
end
