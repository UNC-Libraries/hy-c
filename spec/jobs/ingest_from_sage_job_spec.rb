# frozen_string_literal: true
require 'rails_helper'

RSpec.describe IngestFromSageJob, type: :job do
  let(:job) { IngestFromSageJob.new }

  let(:permission_template) do
    FactoryBot.create(:permission_template, source_id: admin_set.id)
  end
  let(:workflow) do
    FactoryBot.create(:workflow, permission_template_id: permission_template.id, active: true)
  end

  let(:admin) { FactoryBot.create(:admin) }

  let(:admin_set) do
    FactoryBot.create(:admin_set, title: ['Open_Access_Articles_and_Book_Chapters'])
  end
  let(:workflow_state) do
    FactoryBot.create(:workflow_state, workflow_id: workflow.id, name: 'deposited')
  end
  let(:temp_storage) { Dir.mktmpdir }

  around do |example|
    cached_sage = ENV['INGEST_SAGE_PATH']
    cached_temp_storage = ENV['TEMP_STORAGE']
    ENV['INGEST_SAGE_PATH'] = 'spec/fixtures/sage'
    ENV['TEMP_STORAGE'] = temp_storage.to_s
    example.run
    ENV['INGEST_SAGE_PATH'] = cached_sage
    ENV['TEMP_STORAGE'] = cached_temp_storage
  end

  before do
    ActiveFedora::Cleaner.clean!
    admin_set
    permission_template
    workflow
    workflow_state
    # return the FactoryBot admin user when searching for uid: admin from config
    allow(User).to receive(:find_by).with(uid: 'admin').and_return(admin)
    # return the FactoryBot admin_set when searching for admin set from config
    allow(AdminSet).to receive(:where).with(title: 'Open_Access_Articles_and_Book_Chapters').and_return([admin_set])
    # stub virus checking
    allow(Hyrax::VirusCheckerService).to receive(:file_has_virus?) { false }
    # stub longleaf job
    allow(RegisterToLongleafJob).to receive(:perform_later).and_return(nil)
    # stub FITS characterization
    allow(CharacterizeJob).to receive(:perform_later)
  end

  it 'triggers proquest ingest' do
    expect { job.perform }.to change { Article.count }.by(5).and change { DepositRecord.count }.by(1)
    statuses = Tasks::IngestStatusService.status_service_for_provider('sage').load_statuses
    puts "***STATUS\n#{statuses}"
    expect(statuses['AJH_2021_38_4_10.1177_1049909120951088.zip']['status']).to eq 'Complete'
    expect(statuses['CCX_2021_28_10.1177_1073274820985792.zip']['status']).to eq 'Complete'
    expect(statuses['DHJ_2021_7_10.1177_20552076211037227.zip']['status']).to eq 'Complete'
    expect(statuses['GSJ_2021_11_1_10.1177_2192568219888179.zip']['status']).to eq 'Complete'
    expect(statuses['GSJ_2021_11_1_10.1177_2192568219890573.zip']['status']).to eq 'Complete'
  end
end