# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::IngestHelperUtils::BaseIngestTracker, type: :service do
  let(:output_dir) { '/tmp/test_output' }
  let(:tracker_path) { File.join(output_dir, described_class::TRACKER_FILENAME) }

  let(:config) do
    {
      'time' => Time.new(2025, 10, 6, 10, 0, 0),
      'restart_time' => Time.new(2025, 10, 7, 11, 0, 0),
      'start_date' => Date.new(2025, 10, 1),
      'end_date' => Date.new(2025, 10, 6),
      'admin_set_title' => 'Example Admin Set',
      'depositor_onyen' => 'jdoe',
      'output_dir' => output_dir,
      'full_text_dir' => '/tmp/full_text'
    }
  end

  before do
    allow(LogUtilsHelper).to receive(:double_log)
  end

  describe '.build' do
    it 'creates a new tracker when not resuming' do
      allow(File).to receive(:exist?).with(tracker_path).and_return(false)
      instance = described_class.build(config: config, resume: false)

      expect(instance).to be_a(described_class)
      expect(instance.data).to include('start_time', 'admin_set_title')
      expect(LogUtilsHelper).to have_received(:double_log)
        .with('Initializing new ingest tracker.', :info, tag: 'Tasks::IngestHelperUtils::BaseIngestTracker')
    end

    it 'resumes tracker when resume flag is true and file exists' do
      allow(File).to receive(:exist?).with(tracker_path).and_return(true)
      allow_any_instance_of(described_class).to receive(:load_tracker_file)
        .and_return({ 'progress' => { 'sent' => false } })

      instance = described_class.build(config: config, resume: true)
      expect(instance.data).to include('restart_time')
      expect(LogUtilsHelper).to have_received(:double_log)
        .with('Resuming ingest from previous tracker state.', :info, tag: 'Tasks::IngestHelperUtils::BaseIngestTracker')
    end

    it 'saves after initialization' do
      allow(File).to receive(:exist?).and_return(false)
      allow(File).to receive(:open)
      instance = described_class.build(config: config, resume: false)
      expect(File).to have_received(:open).with(tracker_path, 'w', encoding: 'utf-8')
      expect(instance).to be_a(described_class)
    end
  end

  describe '#initialize' do
    it 'sets @path and empty @data' do
      tracker = described_class.new(config)
      expect(tracker.path).to eq(tracker_path)
      expect(tracker.data).to eq({})
    end
  end

  describe '#[] and #[]=' do
    it 'stores and retrieves values from @data' do
      tracker = described_class.new(config)
      tracker['foo'] = 'bar'
      expect(tracker['foo']).to eq('bar')
    end
  end

  describe '#save' do
    let(:tracker) { described_class.new(config) }

    it 'writes JSON to the tracker file' do
      tracker['x'] = 'y'
      io = StringIO.new
      allow(File).to receive(:open).with(tracker_path, 'w', encoding: 'utf-8').and_yield(io)

      tracker.save
      io.rewind
      json = JSON.parse(io.string)
      expect(json['x']).to eq('y')
    end

    it 'logs an error if writing fails' do
      allow(File).to receive(:open).and_raise(StandardError, 'Disk full')
      tracker.save
      expect(LogUtilsHelper).to have_received(:double_log)
        .with(a_string_including('Failed to save ingest tracker: Disk full'), :error, tag: 'Ingest Tracker')
    end
  end

  describe '#resume!' do
    let(:tracker) { described_class.new(config) }

    it 'loads tracker data and sets restart_time' do
      allow(tracker).to receive(:load_tracker_file).and_return({ 'progress' => {} })
      result = tracker.resume!(config)

      expect(result).to include('progress')
      expect(result['restart_time']).to match(/\d{4}-\d{2}-\d{2}/)
      expect(LogUtilsHelper).to have_received(:double_log)
        .with('Resuming ingest from previous tracker state.', :info, tag: 'Tasks::IngestHelperUtils::BaseIngestTracker')
    end
  end

  describe '#initialize_new!' do
    let(:tracker) { described_class.new(config) }

    it 'sets @data with expected base fields' do
      tracker.initialize_new!(config)
      expect(tracker.data).to include('start_time', 'admin_set_title', 'date_range', 'output_dir')
      expect(tracker.data['depositor_onyen']).to eq('jdoe')
    end
  end

  describe '#load_tracker_file' do
    let(:tracker) { described_class.new(config) }

    it 'returns parsed data when file exists' do
      json_data = { 'key' => 'value' }.to_json
      allow(File).to receive(:read).with(tracker_path, encoding: 'utf-8').and_return(json_data)

      result = tracker.send(:load_tracker_file)
      expect(result).to eq({ 'key' => 'value' })
      expect(LogUtilsHelper).to have_received(:double_log)
        .with(a_string_including('Found existing ingest tracker'), :info, tag: 'Ingest Tracker')
    end

    it 'logs and returns empty hash on error' do
      allow(File).to receive(:read).and_raise(StandardError, 'Permission denied')
      result = tracker.send(:load_tracker_file)
      expect(result).to eq({})
      expect(LogUtilsHelper).to have_received(:double_log)
        .with(a_string_including('Failed to load ingest tracker: Permission denied'), :error, tag: 'Ingest Tracker')
    end
  end

  describe '#build_base_tracker' do
    let(:tracker) { described_class.new(config) }

    it 'returns a properly structured hash' do
      base = tracker.send(:build_base_tracker, config)
      expect(base).to include('start_time', 'restart_time', 'date_range', 'admin_set_title')
      expect(base['date_range']['start']).to eq('2025-10-01')
      expect(base['progress']).to eq({})
    end
  end
end
