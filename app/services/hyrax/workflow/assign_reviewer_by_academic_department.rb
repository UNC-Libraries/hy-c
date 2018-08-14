module Hyrax::Workflow::AssignReviewerByAcademicDepartment

  def self.call(target:, **)
    reviewer = find_reviewer_for(department: target.affiliation.first.split(',')[-1])
    permission_template_id = Hyrax::PermissionTemplate.find_by_source_id(target.admin_set_id).id

    # This assigns database permissions, but does not grant permissions on the Fedora object.
    Hyrax::Workflow::PermissionGenerator.call(entity: target, agents: [reviewer],
                                              roles: ['approving'],
                                              workflow: Sipity::Workflow.where(permission_template_id: permission_template_id, active: true).first)

    # This grants read access to the Fedora object.
    ::AssignPermissionsToWorkJob.perform_later(target.class.name,
                                               target.id,
                                               target.affiliation.to_s.downcase+'_reviewer',
                                               'group',
                                               'read')
  end

  def self.find_reviewer_for(department:)
    Role.where(name: department.strip.to_s.downcase.gsub(' ', '_')+'_reviewer').first_or_create
    Sipity::Agent.where(proxy_for_id: department.strip.to_s.downcase.gsub(' ', '_')+'_reviewer',
                        proxy_for_type: 'Hyrax::Group').first_or_create
  end
end
