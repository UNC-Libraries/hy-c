# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::NASAIngest::Backlog::NASAIngestCoordinatorService do
  let!(:log_calls) { [] }
  let(:admin_set) { FactoryBot.build(:admin_set, title: ['NASA Admin Set']) }
  let(:config) do
    {
      'start_time' => DateTime.new(2024, 1, 1),
      'restart_time' => nil,
      'resume' => false,
      'admin_set_title' => admin_set.title,
      'depositor_onyen' => 'testuser',
      'output_dir' => '/tmp/nasa_ingest_output',
      'nasa_csv_path' => '/tmp/nasa_data.csv',
      'nasa_files_dir' => '/tmp/nasa_files'
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
  let(:md_ingest_service) { instance_double(Tasks::NASAIngest::Backlog::Utilities::MetadataIngestService) }
  let(:file_attachment_service) { instance_double(Tasks::NASAIngest::Backlog::Utilities::FileAttachmentService) }
  let(:aggregator) { instance_double(Tasks::NASAIngest::Backlog::Utilities::FileAttachmentResultAggregator) }
  let(:notification_service) { instance_double(Tasks::NASAIngest::Backlog::Utilities::NotificationService) }

  subject(:coordinator) { described_class.new(config) }

  before do
    allow(Tasks::NASAIngest::Backlog::Utilities::NASAIngestTracker).to receive(:build).and_return(tracker)
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
      expect(Tasks::NASAIngest::Backlog::Utilities::NASAIngestTracker).to receive(:build)
        .with(config: config, resume: false)
      expect(FileUtils).to receive(:mkdir_p).at_least(:once)

      described_class.new(config)
    end

    it 'sets up correct file paths' do
      expect(coordinator.instance_variable_get(:@md_ingest_results_path))
        .to eq('/tmp/nasa_ingest_output/01_load_and_ingest_metadata/metadata_ingest_results.jsonl')
      expect(coordinator.instance_variable_get(:@file_attachment_results_path))
        .to eq('/tmp/nasa_ingest_output/02_attach_files_to_works/attachment_results.jsonl')
      expect(coordinator.instance_variable_get(:@aggregated_file_attachment_results_path))
        .to eq('/tmp/nasa_ingest_output/02_attach_files_to_works/aggregated_attachment_results.jsonl')
      expect(coordinator.instance_variable_get(:@generated_results_csv_dir))
        .to eq('/tmp/nasa_ingest_output/03_generate_result_csvs')
    end
  end

  describe '#run' do
    before do
      allow(Tasks::NASAIngest::Backlog::Utilities::MetadataIngestService).to receive(:new).and_return(md_ingest_service)
      allow(Tasks::NASAIngest::Backlog::Utilities::FileAttachmentService).to receive(:new).and_return(file_attachment_service)
      allow(Tasks::NASAIngest::Backlog::Utilities::FileAttachmentResultAggregator).to receive(:new).and_return(aggregator)
      allow(Tasks::NASAIngest::Backlog::Utilities::NotificationService).to receive(:new).and_return(notification_service)
      allow(md_ingest_service).to receive(:process_backlog)
      allow(file_attachment_service).to receive(:run)
      allow(aggregator).to receive(:aggregate_results)
      allow(notification_service).to receive(:run)
    end

    it 'executes the full ingest workflow with email suppression' do
      expect(NotificationUtilsHelper).to receive(:suppress_emails).and_yield
      expect(md_ingest_service).to receive(:process_backlog)
      expect(file_attachment_service).to receive(:run)
      expect(aggregator).to receive(:aggregate_results)
      expect(notification_service).to receive(:run)

      coordinator.run

      expect(log_calls).to include(['NASA ingest workflow completed successfully.', :info, { tag: 'NASAIngestCoordinator' }])
    end

    it 'logs error if workflow fails' do
      allow(md_ingest_service).to receive(:process_backlog).and_raise(StandardError.new('Ingest failed'))

      expect {
        coordinator.run
      }.to raise_error(StandardError, 'Ingest failed')

      expect(log_calls).to include(['NASA ingest workflow failed: Ingest failed', :error, { tag: 'NASAIngestCoordinator' }])
    end

    it 'runs notification outside email suppression' do
      # The notification step should be called after suppress_emails block
      expect(NotificationUtilsHelper).to receive(:suppress_emails).and_yield.ordered
      expect(notification_service).to receive(:run).ordered

      coordinator.run
    end
  end

  describe '#load_and_ingest_metadata' do
    before do
      allow(Tasks::NASAIngest::Backlog::Utilities::MetadataIngestService).to receive(:new).and_return(md_ingest_service)
      allow(md_ingest_service).to receive(:process_backlog)
    end

    it 'runs metadata ingest service and marks complete' do
      coordinator.send(:load_and_ingest_metadata)

      expect(Tasks::NASAIngest::Backlog::Utilities::MetadataIngestService).to have_received(:new).with(
        config: config,
        tracker: tracker,
        md_ingest_results_path: '/tmp/nasa_ingest_output/01_load_and_ingest_metadata/metadata_ingest_results.jsonl'
      )
      expect(md_ingest_service).to have_received(:process_backlog)
      expect(tracker_hash['progress']['metadata_ingest']['completed']).to be true
      expect(tracker).to have_received(:save)
    end

    it 'logs start and completion messages' do
      coordinator.send(:load_and_ingest_metadata)

      expect(log_calls).to include(['Starting metadata ingest step.', :info, { tag: 'NASAIngestCoordinatorService' }])
      expect(log_calls).to include(['Metadata ingest step completed.', :info, { tag: 'NASAIngestCoordinatorService' }])
    end

    it 'skips if already completed' do
      tracker_hash['progress']['metadata_ingest']['completed'] = true

      coordinator.send(:load_and_ingest_metadata)

      expect(md_ingest_service).not_to have_received(:process_backlog)
      expect(log_calls).to include(['Metadata ingest already completed according to tracker. Skipping this step.', :info, { tag: 'NASAIngestCoordinatorService' }])
    end
  end

  describe '#attach_files' do
    before do
      allow(Tasks::NASAIngest::Backlog::Utilities::FileAttachmentService).to receive(:new).and_return(file_attachment_service)
      allow(Tasks::NASAIngest::Backlog::Utilities::FileAttachmentResultAggregator).to receive(:new).and_return(aggregator)
      allow(file_attachment_service).to receive(:run)
      allow(aggregator).to receive(:aggregate_results)
    end

    it 'runs file attachment service, aggregates results, and marks complete' do
      coordinator.send(:attach_files)

      expect(Tasks::NASAIngest::Backlog::Utilities::FileAttachmentService).to have_received(:new).with(
        config: config,
        tracker: tracker,
        log_file_path: '/tmp/nasa_ingest_output/02_attach_files_to_works/attachment_results.jsonl',
        metadata_ingest_result_path: '/tmp/nasa_ingest_output/01_load_and_ingest_metadata/metadata_ingest_results.jsonl'
      )
      expect(file_attachment_service).to have_received(:run)
      expect(aggregator).to have_received(:aggregate_results)
      expect(tracker_hash['progress']['attach_files_to_works']['completed']).to be true
      expect(tracker).to have_received(:save)
    end

    it 'creates aggregator with correct paths' do
      coordinator.send(:attach_files)

      expect(Tasks::NASAIngest::Backlog::Utilities::FileAttachmentResultAggregator).to have_received(:new).with(
        attachment_results_path: '/tmp/nasa_ingest_output/02_attach_files_to_works/attachment_results.jsonl',
        output_path: '/tmp/nasa_ingest_output/02_attach_files_to_works/aggregated_attachment_results.jsonl'
      )
    end

    it 'logs start, aggregation, and completion messages' do
      coordinator.send(:attach_files)

      expect(log_calls).to include(['Starting file attachment step.', :info, { tag: 'NASAIngestCoordinatorService' }])
      expect(log_calls).to include(['Aggregating file attachment results.', :info, { tag: 'NASAIngestCoordinatorService' }])
      expect(log_calls).to include(['File attachment step completed.', :info, { tag: 'NASAIngestCoordinatorService' }])
    end

    it 'skips if already completed' do
      tracker_hash['progress']['attach_files_to_works']['completed'] = true

      coordinator.send(:attach_files)

      expect(file_attachment_service).not_to have_received(:run)
      expect(aggregator).not_to have_received(:aggregate_results)
      expect(log_calls).to include(['File attachment already completed according to tracker. Skipping this step.', :info, { tag: 'NASAIngestCoordinatorService' }])
    end
  end

  describe '#format_results_and_notify' do
    before do
      allow(Tasks::NASAIngest::Backlog::Utilities::NotificationService).to receive(:new).and_return(notification_service)
      allow(notification_service).to receive(:run)
    end

    it 'runs notification service and marks complete' do
      coordinator.send(:format_results_and_notify)

      expect(Tasks::NASAIngest::Backlog::Utilities::NotificationService).to have_received(:new).with(
        config: config,
        tracker: tracker,
        output_dir: '/tmp/nasa_ingest_output/03_generate_result_csvs',
        file_attachment_results_path: '/tmp/nasa_ingest_output/02_attach_files_to_works/aggregated_attachment_results.jsonl',
        max_display_rows: 100
      )
      expect(notification_service).to have_received(:run)
      expect(tracker_hash['progress']['send_summary_email']['completed']).to be true
      expect(tracker).to have_received(:save)
    end

    it 'logs start and completion messages' do
      coordinator.send(:format_results_and_notify)

      expect(log_calls).to include(['Starting results formatting and notification step.', :info, { tag: 'NASAIngestCoordinatorService' }])
      expect(log_calls).to include(['Results formatting and notification step completed.', :info, { tag: 'NASAIngestCoordinatorService' }])
    end

    it 'skips if already completed' do
      tracker_hash['progress']['send_summary_email']['completed'] = true

      coordinator.send(:format_results_and_notify)

      expect(notification_service).not_to have_received(:run)
      expect(log_calls).to include(['Results formatting and notification already completed according to tracker. Skipping this step.', :info, { tag: 'NASAIngestCoordinatorService' }])
    end
  end

  describe '#generate_output_subdirectories' do
    it 'creates all output subdirectories' do
      allow(Dir).to receive(:exist?).and_return(false)

      coordinator.generate_output_subdirectories

      expect(FileUtils).to have_received(:mkdir_p).with('/tmp/nasa_ingest_output/01_load_and_ingest_metadata').at_least(:once)
      expect(FileUtils).to have_received(:mkdir_p).with('/tmp/nasa_ingest_output/02_attach_files_to_works').at_least(:once)
      expect(FileUtils).to have_received(:mkdir_p).with('/tmp/nasa_ingest_output/03_generate_result_csvs').at_least(:once)
    end

    it 'does not create directories that already exist' do
      allow(Dir).to receive(:exist?).and_return(true)

      coordinator.generate_output_subdirectories

      expect(FileUtils).not_to have_received(:mkdir_p)
    end
  end
end
