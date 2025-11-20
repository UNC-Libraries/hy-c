# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::EricIngest::Backlog::EricIngestCoordinatorService do
  let(:admin_set) { FactoryBot.build(:admin_set, title: ['ERIC Ingest Admin Set']) }
  let(:config) do
    {
      'start_time' => DateTime.new(2024, 1, 1),
      'restart_time' => nil,
      'resume' => false,
      'admin_set_title' => admin_set.title,
      'depositor_onyen' => 'testuser',
      'output_dir' => '/tmp/eric_ingest_output',
      'full_text_dir' => '/tmp/eric_full_text'
    }
  end

  let(:tracker_hash) do
    {
      'depositor_onyen' => 'testuser',
      'progress' => {
        'metadata_ingest' => { 'completed' => false },
        'attach_files_to_works' => { 'completed' => false },
        'send_summary_email' => { 'completed' => false }
      }
    }.with_indifferent_access
  end

  let(:tracker) do
    double('Tracker', save: true).tap do |t|
      allow(t).to receive(:[]) { |key| tracker_hash[key] }
      allow(t).to receive(:[]=) { |key, value| tracker_hash[key] = value }
      allow(t).to receive(:dig) do |*keys|
        keys.reduce(tracker_hash) { |acc, k| acc[k] if acc }
      end
    end
  end

  let(:md_ingest_service) { instance_double(Tasks::EricIngest::Backlog::Utilities::MetadataIngestService) }
  let(:file_attachment_service) { instance_double(Tasks::EricIngest::Backlog::Utilities::FileAttachmentService) }
  let(:notification_service) { instance_double(Tasks::EricIngest::Backlog::Utilities::NotificationService) }

  subject(:coordinator) { described_class.new(config) }

  before do
    allow(Tasks::EricIngest::Backlog::Utilities::EricIngestTracker).to receive(:build).and_return(tracker)
    allow(LogUtilsHelper).to receive(:double_log)
    allow(Rails.logger).to receive(:error)
    allow(NotificationUtilsHelper).to receive(:suppress_emails).and_yield
    allow(FileUtils).to receive(:mkdir_p)
    allow(Dir).to receive(:exist?).and_return(false)
  end

  describe '#initialize' do
    it 'builds tracker and creates output directories' do
      expect(Tasks::EricIngest::Backlog::Utilities::EricIngestTracker).to receive(:build)
        .with(config: config, resume: false)
      expect(FileUtils).to receive(:mkdir_p).at_least(:once)

      described_class.new(config)
    end
  end

  describe '#run' do
    before do
      allow(coordinator).to receive(:load_and_ingest_metadata)
      allow(coordinator).to receive(:attach_files)
      allow(coordinator).to receive(:format_results_and_notify)
    end

    it 'runs full workflow with email suppression' do
      expect(NotificationUtilsHelper).to receive(:suppress_emails).and_yield
      expect(coordinator).to receive(:load_and_ingest_metadata)
      expect(coordinator).to receive(:attach_files)
      expect(coordinator).to receive(:format_results_and_notify)

      coordinator.run

      expect(LogUtilsHelper).to have_received(:double_log)
        .with('ERIC ingest workflow completed successfully.', :info, tag: 'EricIngestCoordinator')
    end

    it 'logs error if workflow fails' do
      allow(coordinator).to receive(:load_and_ingest_metadata).and_raise(StandardError, 'Test error')

      expect { coordinator.run }.to raise_error(StandardError, 'Test error')

      expect(LogUtilsHelper).to have_received(:double_log)
        .with('ERIC ingest workflow failed: Test error', :error, tag: 'EricIngestCoordinator')
    end
  end

  describe '#load_and_ingest_metadata' do
    it 'runs metadata ingest service and marks complete' do
      allow(Tasks::EricIngest::Backlog::Utilities::MetadataIngestService).to receive(:new).and_return(md_ingest_service)
      allow(md_ingest_service).to receive(:process_backlog)

      coordinator.load_and_ingest_metadata

      expect(Tasks::EricIngest::Backlog::Utilities::MetadataIngestService).to have_received(:new)
        .with(hash_including(config: config, tracker: tracker))
      expect(md_ingest_service).to have_received(:process_backlog)
      expect(tracker_hash['progress']['metadata_ingest']['completed']).to be true
      expect(tracker).to have_received(:save)
    end

    it 'skips if already completed' do
      tracker_hash['progress']['metadata_ingest']['completed'] = true

      expect(Tasks::EricIngest::Backlog::Utilities::MetadataIngestService).not_to receive(:new)

      coordinator.load_and_ingest_metadata

      expect(LogUtilsHelper).to have_received(:double_log)
        .with(/already completed/, :info, tag: 'EricIngestCoordinatorService')
    end
  end

  describe '#attach_files' do
    it 'runs file attachment service and marks complete' do
      allow(Tasks::EricIngest::Backlog::Utilities::FileAttachmentService).to receive(:new).and_return(file_attachment_service)
      allow(file_attachment_service).to receive(:run)

      coordinator.attach_files

      expect(Tasks::EricIngest::Backlog::Utilities::FileAttachmentService).to have_received(:new)
        .with(hash_including(config: config, tracker: tracker))
      expect(file_attachment_service).to have_received(:run)
      expect(tracker_hash['progress']['attach_files_to_works']['completed']).to be true
      expect(tracker).to have_received(:save)
    end

    it 'skips if already completed' do
      tracker_hash['progress']['attach_files_to_works']['completed'] = true

      expect(Tasks::EricIngest::Backlog::Utilities::FileAttachmentService).not_to receive(:new)

      coordinator.attach_files

      expect(LogUtilsHelper).to have_received(:double_log)
        .with(/already completed/, :info, tag: 'EricIngestCoordinatorService')
    end
  end

  describe '#format_results_and_notify' do
    it 'runs notification service and marks complete' do
      allow(Tasks::EricIngest::Backlog::Utilities::NotificationService).to receive(:new).and_return(notification_service)
      allow(notification_service).to receive(:run)

      coordinator.format_results_and_notify

      expect(Tasks::EricIngest::Backlog::Utilities::NotificationService).to have_received(:new)
        .with(hash_including(config: config, tracker: tracker))
      expect(notification_service).to have_received(:run)
      expect(tracker_hash['progress']['send_summary_email']['completed']).to be true
      expect(tracker).to have_received(:save)
    end

    it 'skips if already completed' do
      tracker_hash['progress']['send_summary_email']['completed'] = true

      expect(Tasks::EricIngest::Backlog::Utilities::NotificationService).not_to receive(:new)

      coordinator.format_results_and_notify

      expect(LogUtilsHelper).to have_received(:double_log)
        .with(/already completed/, :info, tag: 'EricIngestCoordinatorService')
    end
  end

  describe '#generate_output_subdirectories' do
    it 'creates all output subdirectories' do
      allow(Dir).to receive(:exist?).and_return(false)

      coordinator.generate_output_subdirectories

      expect(FileUtils).to have_received(:mkdir_p).with(/01_load_and_ingest_metadata/).at_least(:once)
      expect(FileUtils).to have_received(:mkdir_p).with(/02_attach_files_to_works/).at_least(:once)
      expect(FileUtils).to have_received(:mkdir_p).with(/03_generate_result_csvs/).at_least(:once)
    end
  end
end
