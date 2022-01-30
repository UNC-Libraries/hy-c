require 'rails_helper'

RSpec.describe Tasks::IngestService, :ingest do
  let(:args) { { configuration_file: path_to_config } }
  let(:admin_set) { FactoryBot.create(:admin_set, title: [admin_set_title]) }
  let(:admin) { FactoryBot.create(:admin) }
  let(:depositor_uid) { 'admin' }

  before do
    admin_set
    # return the FactoryBot admin user when searching for uid: admin from config
    allow(User).to receive(:find_by).with(uid: depositor_uid).and_return(admin)
  end

  context 'with a proquest ingest' do
    let(:path_to_config) { 'spec/fixtures/proquest/proquest_config.yml' }
    let(:admin_set_title) { 'proquest admin set' }
    let(:service) { Tasks::ProquestIngestService.new(args) }

    it 'can be instantiated' do
      expect(service).to be_instance_of Tasks::ProquestIngestService
      expect(service.temp).to eq('spec/fixtures/proquest/tmp')
      expect(service.admin_set.title).to eq ['proquest admin set']
      expect(service.depositor).to eq(admin)
      expect(service.package_dir).to eq('spec/fixtures/proquest')
      expect(service.ingest_source).to eq('ProQuest')
    end
  end

  context 'with a sage ingest' do
    let(:path_to_config) { 'spec/fixtures/sage/sage_config.yml' }
    let(:admin_set_title) { 'Open_Access_Articles_and_Book_Chapters' }
    let(:service) { Tasks::SageIngestService.new(args) }

    it 'can be instantiated' do
      expect(service).to be_instance_of Tasks::SageIngestService
      expect(service.temp).to eq('spec/fixtures/sage/tmp')
      expect(service.admin_set.title).to eq ['Open_Access_Articles_and_Book_Chapters']
      expect(service.depositor).to eq(admin)
      expect(service.package_dir).to eq('spec/fixtures/sage')
      expect(service.ingest_source).to eq('Sage')
      expect(service.ingest_progress_log).to be_instance_of(Migrate::Services::ProgressTracker)
    end
  end
end
