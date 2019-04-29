desc "Adds sample data for oai tests"
task :test_data_import => :environment do
  # Set up functional admin set
  admin_user = User.find_by_user_key('admin@example.com')
  admin_set = AdminSet.where(title: 'default admin set').first
  if admin_set.blank?
    admin_set = AdminSet.create(title: ['default admin set'],
                               description: ['some description'],
                               edit_users: [admin_user.user_key])
  end
  permission_template = Hyrax::PermissionTemplate.create!(source_id: admin_set.id)
  Hyrax::PermissionTemplateAccess.where(permission_template: permission_template,
                                         agent_type: 'user',
                                         agent_id: admin_user.user_key,
                                         access: 'deposit').first_or_create
  Hyrax::Workflow::WorkflowImporter.generate_from_json_file(path: Rails.root.join('config',
                                                                                  'workflows',
                                                                                  'default_workflow.json'),
                                                            permission_template: permission_template)
  workflow = Sipity::Workflow.find_by!(name: 'default', permission_template: permission_template)
  admin_agent = Sipity::Agent.where(proxy_for_id: admin_user.id, proxy_for_type: 'User').first_or_create
  Hyrax::Workflow::PermissionGenerator.call(roles: 'approving', workflow: workflow, agents: admin_agent)
  Hyrax::Workflow::PermissionGenerator.call(roles: 'depositing', workflow: workflow, agents: admin_agent)
  Hyrax::Workflow::PermissionGenerator.call(roles: 'deleting', workflow: workflow, agents: admin_agent)

  # Ingest sample data
  sample_data = YAML.load(File.read(File.expand_path('../../../spec/fixtures/oai_sample_documents.yml', __FILE__)))
  sample_data.each do |data|
    doc = data[1]
    work = Article.new
    work.creator = [doc['creator']]
    work.depositor = doc['depositor']
    work.label = doc['label']
    work.title = [doc['title']]
    work.date_created = doc['date_created']
    work.date_modified = doc['date_modified']
    work.contributor = [doc['contributor']]
    work.description = doc['description']
    work.related_url = [doc['related_url']]
    work.resource_type = [doc['resource_type']]
    work.language = [doc['language']]
    work.language_label = [doc['language_label']]
    work.rights_statement = doc['rights_statement']
    work.visibility = doc['visibility']
    work.admin_set_id = AdminSet.first.id
    work.save!
    sleep 1
  end
end