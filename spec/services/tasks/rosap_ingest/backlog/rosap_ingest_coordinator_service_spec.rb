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
end
