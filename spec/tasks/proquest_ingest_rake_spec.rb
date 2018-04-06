require "rails_helper"
require "rake"

describe "rake proquest:ingest", type: :task do
  let(:admin_user) do
    User.find_by_user_key('admin@example.com')
  end

  let(:admin_set) do
    AdminSet.create!(title: ["default"],
                    description: ["some description"])
  end

  let(:permission_template) do
    Hyrax::PermissionTemplate.create!(admin_set_id: admin_set.id)
  end

  let(:workflow) do
    Sipity::Workflow.create!(name: 'test', allows_access_grant: true, active: true,
                            permission_template_id: permission_template.id)
  end

  before do
    Hyrax::PermissionTemplateAccess.create!(permission_template: permission_template,
                                           agent_type: 'user',
                                           agent_id: admin_user.user_key,
                                           access: 'deposit')
    Sipity::WorkflowAction.create(id: 4, name: 'show', workflow_id: workflow.id)
    Hyrax::Application.load_tasks if Rake::Task.tasks.empty?
  end

  it "preloads the Rails environment" do
    expect(Rake::Task['proquest:ingest'].prerequisites).to include "environment"
  end

  it "creates a new work" do
    expect { Rake::Task['proquest:ingest'].invoke('spec/fixtures/proquest', 'default', 'RAILS_ENV=test') }
        .to change{ Dissertation.count }.by(1)
    puts Dissertation.last.as_json
    expect(Dissertation.last['depositor']).to eq 'admin@example.com'
    expect(Dissertation.last['title']).to match_array ['Perspective on Attachments and Ingests']
    expect(Dissertation.last['label']).to eq 'Perspectives on Attachments and Ingests'
    expect(Dissertation.last['date_modified']).to eq DateTime.now.strftime('%Y-%m-%d')
    expect(Dissertation.last['date_modified']).to eq '2011-01-01'
    expect(Dissertation.last['creator']).to match_array ['Smith, Blandy']
    expect(Dissertation.last['contributor']).to match_array ['Smith, Blandy']
    expect(Dissertation.last['keyword']).to match_array ['Philosophy', 'attachments', 'aesthetics']
    expect(Dissertation.last['resource_type']).to match_array ['Dissertation']
    expect(Dissertation.last['abstract']).to match_array ['The purpose of this study is to test ingest of a proquest deposit object without any attachemnts']
    expect(Dissertation.last['academic_concentration']).to match_array ['Philosophy']
    expect(Dissertation.last['advisor']).to match_array ['Advisor, John T']
    expect(Dissertation.last['degree']).to eq 'Ph.D.'
    expect(Dissertation.last['degree_granting_institution']).to eq 'University of North Carolina at Chapel Hill Graduate School'
    expect(Dissertation.last['genre']).to match_array ['Dissertation']
    expect(Dissertation.last['graduation_year']).to eq 'Spring 2014'
  end
end
