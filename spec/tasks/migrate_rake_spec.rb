require "rails_helper"
require "rake"

describe "rake migrate:works", type: :task do
  let(:user) do
    User.find_by_user_key('admin@example.com')
  end

  let(:admin_set) do
    AdminSet.create(title: ['default'],
                    description: ['some description'],
                    edit_users: [user.user_key])
  end

  let(:permission_template) do
    Hyrax::PermissionTemplate.create!(source_id: admin_set.id)
  end

  let(:workflow) do
    Sipity::Workflow.create(name: 'test', allows_access_grant: true, active: true,
                            permission_template_id: permission_template.id)
  end

  before do
    Hyrax::Application.load_tasks if Rake::Task.tasks.empty?
    AdminSet.delete_all
    Hyrax::PermissionTemplateAccess.create(permission_template: permission_template,
                                           agent_type: 'user',
                                           agent_id: user.user_key,
                                           access: 'deposit')
    Sipity::WorkflowAction.create(id: 4, name: 'show', workflow_id: workflow.id)
  end

  it "preloads the Rails environment" do
    expect(Rake::Task['migrate:works'].prerequisites).to include "environment"
  end

  it "creates a new work" do
    expect { Rake::Task['migrate:works'].invoke('collection1',
                                                      'spec/fixtures/migration/migration_config.yml',
                                                      'spec/fixtures/migration/mapping.csv',
                                                      'RAILS_ENV=test') }
        .to change{ Article.count }.by(1)
    new_article = Article.all[-1]
    expect(new_article['depositor']).to eq 'admin@example.com'
    expect(new_article['title']).to match_array ['Les Miserables']
    expect(new_article['label']).to eq 'Les Miserables'
    expect(new_article['date_modified']).to eq '2017-10-02'
    expect(new_article['publisher']).to match_array ['Project Gutenberg']
    expect(new_article['language']).to match_array ['http://id.loc.gov/vocabulary/iso639-2/eng']
    expect(new_article['language_label']).to match_array ['English']
    expect(new_article['license']).to match_array ['http://creativecommons.org/licenses/by/3.0/us/']
    expect(new_article['license_label']).to match_array ['Attribution 3.0 United States']
    expect(new_article['rights_statement']).to eq 'http://rightsstatements.org/vocab/InC/1.0/'
    expect(new_article['rights_statement_label']).to eq 'In Copyright'
    expect(new_article['admin_set_id']).to eq admin_set.id
    expect(new_article.visibility).to eq 'restricted'
    expect(new_article.file_sets.count).to eq 2
    File.delete('spec/fixtures/migration/mapping.csv')
  end
end
