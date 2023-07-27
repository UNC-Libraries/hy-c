# frozen_string_literal: true
require 'rails_helper'

RSpec.describe IngestFromProquestJob, type: :job do
  let(:job) { IngestFromProquestJob.new }

  let(:admin) { FactoryBot.create(:admin) }

  let(:admin_set) do
    AdminSet.create(title: ['Dissertation'],
                    description: ['some description'])
  end

  let(:permission_template) do
    Hyrax::PermissionTemplate.create!(source_id: admin_set.id)
  end

  let(:workflow) do
    Sipity::Workflow.create(name: 'test', allows_access_grant: true, active: true,
                            permission_template_id: permission_template.id)
  end
  let(:temp_storage) { Dir.mktmpdir }

  around do |example|
    cached_proquest = ENV['INGEST_PROQUEST_PATH']
    cached_temp_storage = ENV['TEMP_STORAGE']
    ENV['INGEST_PROQUEST_PATH'] = 'spec/fixtures/proquest'
    ENV['TEMP_STORAGE'] = temp_storage.to_s
    example.run
    ENV['INGEST_PROQUEST_PATH'] = cached_proquest
    ENV['TEMP_STORAGE'] = cached_temp_storage
  end

  before do
    ActiveFedora::Cleaner.clean!
    allow(RegisterToLongleafJob).to receive(:perform_later).and_return(nil)
    allow(User).to receive(:find_by).with(uid: admin.uid).and_return(admin)
    allow(CharacterizeJob).to receive(:perform_later)
    allow(Hyrax::VirusCheckerService).to receive(:file_has_virus?) { false }
    AdminSet.delete_all
    Sipity::WorkflowState.create(workflow_id: workflow.id, name: 'deposited')
  end

  let(:selected_filepaths) { ['spec/fixtures/proquest/proquest-attach0.zip', 'spec/fixtures/proquest/proquest-attach7.zip'] }

  it 'triggers proquest ingest' do
    expect { job.perform(admin.uid, selected_filepaths) }.to change { Dissertation.count }.by(1).and change { DepositRecord.count }.by(1)
    statuses = Tasks::IngestStatusService.status_service_for_source('proquest').load_statuses
    expect(statuses['proquest-attach0.zip']['status']).to eq 'Complete'
    expect(statuses['proquest-attach7.zip']['status']).to eq 'Failed'
  end
end
