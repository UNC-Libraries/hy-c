module Hyrax::Workflow::AssignReviewerByAcademicDepartment

  def self.call(target:, **)
    Rails.logger.info "\n\n##########\n#{target.affiliation}\n###########\n\n"
    Rails.logger.info "\n\n##########\n#{target.affiliation.inspect}\n###########\n\n"
    Rails.logger.info "\n\n##########\n#{target.affiliation.to_a.first}\n###########\n\n"
    Rails.logger.info "\n\n##########\n#{target.affiliation.first}\n###########\n\n"
    Rails.logger.info "\n\n##########\n#{target.inspect}\n###########\n\n"
    reviewer = find_reviewer_for(department: target.affiliation.first.split(',')[-1])
    permission_template_id = Hyrax::PermissionTemplate.find_by_source_id(target.admin_set_id).id

    Rails.logger.info "\n\n##########\n#{target.affiliation.first.strip}\n###########\n\n"
    Rails.logger.info "\n\n##########\n#{reviewer}\n###########\n\n"

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
    Rails.logger.info "\n\n##########\n#{department}\n###########\n\n"

    Sipity::Agent.where(proxy_for_id: department.strip.to_s.downcase.gsub(' ', '_')+'_reviewer',
                        proxy_for_type: 'Hyrax::Group').first_or_create
  end
end
