# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::RosapIngest::Backlog::RosapIngestCoordinatorService do
  let!(:log_calls) { [] }
  let(:admin_set) { FactoryBot.build(:admin_set, title: ['ROSAP Ingest Admin Set']) }
  let(:config) do
    {
        'start_time' => DateTime.new(2024, 1, 1),
        'restart_time' => nil,
        'resume' => false,
        'admin_set_title' => admin_set.title,
        'depositor_onyen' => 'testuser',
        'output_dir' => '/tmp/rosap_ingest_output',
        'full_text_dir' => '/tmp/rosap_full_text'
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
        # Mocking nested dig method
      allow(t).to receive(:dig) do |*keys|
        result = tracker_hash
        keys.each { |k| result = result[k] if result }
        result
      end
    end
  end
  let(:md_ingest_service) { instance_double(Tasks::RosapIngest::Backlog::Utilities::MetadataIngestService) }
  let(:file_attachment_service) { instance_double(Tasks::RosapIngest::Backlog::Utilities::FileAttachmentService) }
  let(:notification_service) { instance_double(Tasks::RosapIngest::Backlog::Utilities::NotificationService) }

  subject(:coordinator) { described_class.new(config) }

  before do
    allow(Tasks::RosapIngest::Backlog::Utilities::RosapIngestTracker).to receive(:build).and_return(tracker)
      # Capture log calls
    allow(LogUtilsHelper).to receive(:double_log) do |*args|
      log_calls << args
    end
    allow(Rails.logger).to receive(:error)
    allow(NotificationUtilsHelper).to receive(:suppress_emails).and_yield
    allow(FileUtils).to receive(:mkdir_p)
    allow(Dir).to receive(:exist?).and_return(false)
  end

  describe '#initialize' do
    it 'builds tracker and creates output directories' do
      expect(Tasks::RosapIngest::Backlog::Utilities::RosapIngestTracker).to receive(:build)
            .with(config: config, resume: false)
      expect(FileUtils).to receive(:mkdir_p).at_least(:once)

      described_class.new(config)
    end
  end

  describe '#run' do
    before do
      allow(Tasks::RosapIngest::Backlog::Utilities::MetadataIngestService).to receive(:new).and_return(md_ingest_service)
      allow(Tasks::RosapIngest::Backlog::Utilities::FileAttachmentService).to receive(:new).and_return(file_attachment_service)
      allow(Tasks::RosapIngest::Backlog::Utilities::NotificationService).to receive(:new).and_return(notification_service)
    end

    it 'executes the full ingest workflow with email suppression' do
      expect(NotificationUtilsHelper).to receive(:suppress_emails).and_yield
      expect(md_ingest_service).to receive(:process_backlog)
      expect(file_attachment_service).to receive(:run)
      expect(notification_service).to receive(:run)

      coordinator.run

      expect(log_calls).to include(['ROSA-P ingest workflow completed successfully.', :info, { tag: 'RosapIngestCoordinator' }])
    end

    it 'logs error if workflow fails' do
      allow(md_ingest_service).to receive(:process_backlog).and_raise(StandardError.new('Ingest failed'))

      expect {
        coordinator.run
      }.to raise_error(StandardError, 'Ingest failed')

      expect(log_calls).to include(['ROSA-P ingest workflow failed: Ingest failed', :error, { tag: 'RosapIngestCoordinator' }])
    end
  end

  describe '#load_and_ingest_metadata' do
    it 'runs metadata ingest service and marks complete' do
      allow(md_ingest_service).to receive(:process_backlog)
      expect(Tasks::RosapIngest::Backlog::Utilities::MetadataIngestService).to receive(:new).and_return(md_ingest_service)

      coordinator.send(:load_and_ingest_metadata)

      expect(tracker_hash['progress']['metadata_ingest']['completed']).to be true
    end

    it 'skips if already completed' do
      tracker_hash['progress']['metadata_ingest']['completed'] = true

      coordinator.send(:load_and_ingest_metadata)

      expect(log_calls).to include(['Metadata ingest already completed according to tracker. Skipping this step.', :info, { tag: 'RosapIngestCoordinatorService' }])
    end
  end

  describe '#attach_files' do
    it 'runs file attachment service and marks complete' do
      allow(file_attachment_service).to receive(:run)
      expect(Tasks::RosapIngest::Backlog::Utilities::FileAttachmentService).to receive(:new).and_return(file_attachment_service)

      coordinator.send(:attach_files)

      expect(tracker_hash['progress']['attach_files_to_works']['completed']).to be true
    end

    it 'skips if already completed' do
      tracker_hash['progress']['attach_files_to_works']['completed'] = true

      coordinator.send(:attach_files)

      expect(log_calls).to include(['File attachment already completed according to tracker. Skipping this step.', :info, { tag: 'RosapIngestCoordinatorService' }])
    end
  end

  describe '#format_results_and_notify' do
    it 'runs notification service and marks complete' do
      allow(notification_service).to receive(:run)
      expect(Tasks::RosapIngest::Backlog::Utilities::NotificationService).to receive(:new).and_return(notification_service)

      coordinator.send(:format_results_and_notify)

      expect(tracker_hash['progress']['send_summary_email']['completed']).to be true
    end

    it 'skips if already completed' do
      tracker_hash['progress']['send_summary_email']['completed'] = true

      coordinator.send(:format_results_and_notify)

      expect(log_calls).to include(['Result formatting and notification already completed according to tracker. Skipping this step.', :info, { tag: 'RosapIngestCoordinatorService' }])
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
