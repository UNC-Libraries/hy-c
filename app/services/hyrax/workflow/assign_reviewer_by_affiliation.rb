module Hyrax::Workflow::AssignReviewerByAffiliation

  def self.call(target:, **)
    target.affiliation.each do |affiliation|
      department = affiliation.strip.to_s.downcase.gsub(' ', '_')
      reviewer = find_reviewer_for(department: department)
      permission_template_id = Hyrax::PermissionTemplate.find_by_source_id(target.admin_set_id).id

      # This assigns database permissions, but does not grant permissions on the Fedora object.
      Hyrax::Workflow::PermissionGenerator.call(entity: target,
                                                agents: [reviewer],
                                                roles: ['approving', 'depositing'],
                                                workflow: Sipity::Workflow.where(permission_template_id: permission_template_id,
                                                                                 active: true).first)

      # This grants read access to the Fedora object.
      ::AssignPermissionsToWorkJob.perform_later(target.class.name,
                                                 target.id,
                                                 department+'_reviewer',
                                                 'group',
                                                 'read')
    end
  end

  def self.find_reviewer_for(department:)
    Role.where(name: department+'_reviewer').first_or_create
    Sipity::Agent.where(proxy_for_id: department+'_reviewer',
                        proxy_for_type: 'Hyrax::Group').first_or_create
  end
end
