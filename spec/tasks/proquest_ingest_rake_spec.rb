require "rails_helper"
require "rake"

describe "rake proquest:ingest", type: :task do
  let(:admin_user) do
    User.find_by_user_key('admin')
  end

  let(:time) do
    Time.now
  end

  let(:admin_set) do
    AdminSet.create!(title: ["proquest default "+time.to_s],
                    description: ["some description"])
  end

  let(:permission_template) do
    Hyrax::PermissionTemplate.create!(source_id: admin_set.id)
  end

  let(:workflow) do
    Sipity::Workflow.create!(name: 'test', allows_access_grant: true, active: true,
                            permission_template_id: permission_template.id)
  end

  before do
    AdminSet.delete_all
    Hyrax::PermissionTemplateAccess.delete_all
    Hyrax::PermissionTemplate.delete_all
    Hyrax::PermissionTemplateAccess.create!(permission_template: permission_template,
                                           agent_type: 'user',
                                           agent_id: admin_user.user_key,
                                           access: 'deposit')
    Sipity::WorkflowAction.create(name: 'show', workflow_id: workflow.id)
    Hyrax::Application.load_tasks if Rake::Task.tasks.empty?
  end

  it "preloads the Rails environment" do
    expect(Rake::Task['proquest:ingest'].prerequisites).to include "environment"
  end

  it "creates a new work" do
    expect { Rake::Task['proquest:ingest'].invoke('spec/fixtures/proquest/proquest_config.yml', 'RAILS_ENV=test') }
        .to change{ Dissertation.count }.by(1)
    new_dissertation = Dissertation.all[-1]
    expect(new_dissertation['depositor']).to eq 'admin'
    expect(new_dissertation['title']).to match_array ['Perspective on Attachments and Ingests']
    expect(new_dissertation['label']).to eq 'Perspective on Attachments and Ingests'
    expect(new_dissertation['date_issued']).to eq '2011-01-01'
    expect(new_dissertation['creators'][0]['name']).to match_array ['Smith, Blandy']
    expect(new_dissertation['keyword']).to match_array ['Philosophy', 'attachments', 'aesthetics']
    expect(new_dissertation['resource_type']).to match_array ['Dissertation']
    expect(new_dissertation['abstract']).to match_array ['The purpose of this study is to test ingest of a proquest deposit object without any attachments']
    expect(new_dissertation['advisors'][0]['name']).to match_array ['Advisor, John T']
    expect(new_dissertation['degree']).to eq 'Ph.D.'
    expect(new_dissertation['degree_granting_institution']).to eq 'University of North Carolina at Chapel Hill Graduate School'
    expect(new_dissertation['dcmi_type']).to match_array ['Dissertation']
    expect(new_dissertation['graduation_year']).to eq 'Spring 2014'
  end
end
