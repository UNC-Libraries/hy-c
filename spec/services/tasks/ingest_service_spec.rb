# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::IngestService, :ingest do
  let(:args) { { configuration_file: path_to_config } }
  let(:admin_set) { FactoryBot.create(:admin_set, title: [admin_set_title]) }
  let(:admin) { FactoryBot.create(:admin) }
  let(:depositor_uid) { 'admin' }

  before do
    ActiveFedora::Cleaner.clean!
    admin_set
    # return the FactoryBot admin user when searching for uid: admin from config
    allow(User).to receive(:find_by).with(uid: depositor_uid).and_return(admin)
  end

  context 'with a proquest ingest' do
    let(:config) { 
      {
        'unzip_dir' => 'spec/fixtures/proquest/tmp',
        'package_dir' => 'spec/fixtures/proquest',
        'admin_set' => 'proquest admin set',
        'depositor_onyen' => 'admin',
        'deposit_title' => 'Deposit by ProQuest Depositor via CDR Collector 1.0',
        'deposit_method' => 'CDR Collector 1.0',
        'deposit_type' => 'http://proquest.com'
      }
    }
    let(:admin_set_title) { 'proquest admin set' }
    let(:status_service) { Tasks::IngestStatusService.new('spec/fixtures/proquest/tmp/proquest_deposit_status.json') }
    after do
      FileUtils.rm_rf(Dir.glob('spec/fixtures/proquest/tmp/*'))
    end
    let(:service) { Tasks::ProquestIngestService.new(config, status_service) }

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
    let(:config) { 
      {
        'unzip_dir' => 'spec/fixtures/sage/tmp',
        'package_dir' => 'spec/fixtures/sage',
        'admin_set' => 'Open_Access_Articles_and_Book_Chapters',
        'depositor_onyen' => 'admin',
        'ingest_progress_log' => 'spec/fixtures/sage/ingest_progress.log'
      }
    }
    let(:admin_set_title) { 'Open_Access_Articles_and_Book_Chapters' }
    let(:status_service) { Tasks::IngestStatusService.new('spec/fixtures/proquest/tmp/sage_deposit_status.json') }
    after do
      FileUtils.rm_rf(Dir.glob('spec/fixtures/sage/tmp/*'))
    end
    let(:service) { Tasks::SageIngestService.new(config, status_service) }

    it 'can be instantiated' do
      expect(service).to be_instance_of Tasks::SageIngestService
      expect(service.temp).to eq('spec/fixtures/sage/tmp')
      expect(service.admin_set.title).to eq ['Open_Access_Articles_and_Book_Chapters']
      expect(service.depositor).to eq(admin)
      expect(service.package_dir).to eq('spec/fixtures/sage')
      expect(service.ingest_source).to eq('Sage')
      expect(service.ingest_progress_log).to be_instance_of(Migrate::Services::ProgressTracker)
    end

    it 'only creates a single deposit record per service instance' do
      expect do
        service.deposit_record
        service.deposit_record
      end.to change { DepositRecord.count }.by(1)
    end
  end
end
