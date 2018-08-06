require "rails_helper"
require "rake"

describe "rake cdr:migration:items", type: :task do
  let(:user) do
    User.new(email: 'test@example.com', guest: false, uid: 'test@example.com') { |u| u.save!(validate: false)}
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
    expect(Rake::Task['cdr:migration:items'].prerequisites).to include "environment"
  end

  it "creates a new work" do
    expect { Rake::Task['cdr:migration:items'].invoke('collection1',
                                                      'spec/fixtures/migration/mapping.csv',
                                                      'RAILS_ENV=test') }
        .to change{ Article.count }.by(1)
    new_article = Article.all[-1]
    expect(new_article['depositor']).to eq 'admin@example.com'
    expect(new_article['title']).to match_array ['Les Miserables']
    expect(new_article['label']).to eq 'Les Miserables'
    expect(new_article['date_created']).to match_array '2017-10-02'
    expect(new_article['date_modified']).to eq '2017-10-02'
    expect(new_article['creator']).to match_array ['Hugo, Victor']
    expect(new_article['contributor']).to match_array ['Hugo, Victor']
    expect(new_article['publisher']).to match_array ['Project Gutenberg']
    expect(new_article['admin_set_id']).to eq admin_set.id
    File.delete('spec/fixtures/migration/mapping.csv')
  end
end
