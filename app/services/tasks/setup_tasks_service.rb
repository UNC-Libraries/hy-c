# these tasks are used during vm and test env setup
module Tasks
  class SetupTasksService
    def self.admin_role
      User.where(email: 'admin@example.com', uid: 'admin')
          .first_or_create(password: 'password', password_confirmation: 'password')
      admin = Role.where(name: 'admin').first_or_create
      admin.users << User.find_by_user_key('admin')
      admin.save
    end

    def self.default_admin_set
      Hyrax::AdminSetCreateService.call(admin_set: AdminSet.new(title: ['default']),
                                        creating_user: User.where(email: 'admin@example.com').first)
    end

    def self.new_user(email)
      User.where(email: email, uid: email.split('@').first)
          .first_or_create(password: 'password', password_confirmation: 'password')
    end

    def self.test_data_import
      sample_data = YAML.load(File.read(File.expand_path('../../../../spec/fixtures/oai_sample_documents.yml', __FILE__)))
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
        work.save!
        sleep 1
      end
    end
  end
end
