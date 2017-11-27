module Hyrax::Workflow::AssignReviewerByDepartment
  def self.call(target:, **)
    Rails.logger.info "\n\n################\nhi\n###################\n\n"
    Rails.logger.info "\n#########\n"+target.as_json.to_s+"\n###########\n"
    Rails.logger.info "\n#########\n"+target.academic_department.as_json.to_s+"\n###########\n"
    reviewer = find_reviewer_for(department: target.academic_department)
    Rails.logger.info "\n#########\n"+reviewer.to_s+"\n###########\n"
    # This assigns database permissions, but does not grant permissions on the Fedora object.
    Hyrax::Workflow::PermissionGenerator.call(entity: target, agents: [reviewer], roles: ['Reviewer'],
                                              workflow: Sipity::Workflow.find_by_name('one_step_mediated_deposit'))
    # Do you want to update the Fedora object? Then you'll need to make adjustments.
  end

  def self.find_reviewer_for(department:)
    ReviewersService.label(department)
  end
end
