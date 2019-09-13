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
    allow(Date).to receive(:today).and_return(Date.parse('2019-09-12'))
  end

  it "preloads the Rails environment" do
    expect(Rake::Task['proquest:ingest'].prerequisites).to include "environment"
  end

  it "creates a new work" do
    expect { Rake::Task['proquest:ingest'].invoke('spec/fixtures/proquest/proquest_config.yml', 'RAILS_ENV=test') }
        .to change{ Dissertation.count }.by(7)
    dissertations = Dissertation.all
    dissertation1 = dissertations[-7]
    dissertation2 = dissertations[-6]
    dissertation3 = dissertations[-5]
    dissertation4 = dissertations[-4]
    dissertation5 = dissertations[-3]
    dissertation6 = dissertations[-2]
    dissertation7 = dissertations[-1]

    # first dissertation - embargo code: 3, publication year: 2019
    expect(dissertation1['depositor']).to eq 'admin'
    expect(dissertation1['title']).to match_array ['Perspective on Attachments and Ingests']
    expect(dissertation1['label']).to eq 'Perspective on Attachments and Ingests'
    expect(dissertation1['date_issued']).to eq '2019'
    expect(dissertation1['creators'][0]['name']).to match_array ['Smith, Blandy']
    expect(dissertation1['keyword']).to match_array ['Philosophy', 'attachments', 'aesthetics']
    expect(dissertation1['resource_type']).to match_array ['Dissertation']
    expect(dissertation1['abstract']).to match_array ['The purpose of this study is to test ingest of a proquest deposit object without any attachments']
    expect(dissertation1['advisors'][0]['name']).to match_array ['Advisor, John T']
    expect(dissertation1['degree']).to eq 'Doctor of Philosophy'
    expect(dissertation1['degree_granting_institution']).to eq 'University of North Carolina at Chapel Hill Graduate School'
    expect(dissertation1['dcmi_type']).to match_array ['http://purl.org/dc/dcmitype/Text']
    expect(dissertation1['graduation_year']).to eq '2019'
    expect(dissertation1.visibility).to eq 'restricted'
    expect(dissertation1.embargo_release_date).to eq (Date.today.to_datetime + 2.years)

    # second dissertation - embargo code: 2, publication year: 2019
    expect(dissertation2['date_issued']).to eq '2019'
    expect(dissertation2['graduation_year']).to eq '2019'
    expect(dissertation2['resource_type']).to match_array ['Masters Thesis']
    expect(dissertation2.visibility).to eq 'restricted'
    expect(dissertation2.embargo_release_date).to eq (Date.today.to_datetime + 1.year)

    # third dissertation - embargo code: 3, publication year: 2017
    expect(dissertation3['date_issued']).to eq '2017'
    expect(dissertation3['graduation_year']).to eq '2019'
    expect(dissertation3.visibility).to eq 'restricted'
    expect(dissertation3.embargo_release_date).to eq Date.parse('2019-12-31').to_datetime

    # fourth dissertation - embargo code: 4, publication year: 2019
    expect(dissertation4['date_issued']).to eq '2019'
    expect(dissertation4['graduation_year']).to eq '2019'
    expect(dissertation4.visibility).to eq 'restricted'
    expect(dissertation4.embargo_release_date).to eq (Date.today.to_datetime + 2.years)

    # fifth dissertation - embargo code: 0, publication year: 2018
    expect(dissertation5['date_issued']).to eq '2018'
    expect(dissertation5['graduation_year']).to eq '2019'
    expect(dissertation5.visibility).to eq 'open'
    expect(dissertation5.embargo_release_date).to be_nil

    # sixth dissertation - embargo code: 4, publication year: 2018
    expect(dissertation6['date_issued']).to eq '2018'
    expect(dissertation6['graduation_year']).to eq '2019'
    expect(dissertation6.visibility).to eq 'restricted'
    expect(dissertation6.embargo_release_date).to eq Date.parse('2020-12-31').to_datetime

    # seventh dissertation - embargo code: 2, publication year: 2018
    expect(dissertation7['date_issued']).to eq '2018'
    expect(dissertation7['graduation_year']).to eq '2019'
    expect(dissertation7.visibility).to eq 'restricted'
    expect(dissertation7.embargo_release_date).to eq Date.parse('2019-12-31').to_datetime
  end
end
