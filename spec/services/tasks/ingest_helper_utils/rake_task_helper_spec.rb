# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::IngestHelperUtils::RakeTaskHelper do
  include described_class

  let(:time) { Time.new(2025, 11, 10, 14, 30, 0) }
  let(:base_dir) { '/tmp/test_ingest' }

  before do
    allow(Rails).to receive_message_chain(:root, :join) { |arg| "/app/#{arg}" }
    allow(Rails).to receive(:logger).and_return(double(info: nil))
    FileUtils.mkdir_p(base_dir) unless Dir.exist?(base_dir)
  end

  describe '#validate_args!' do
    it 'passes when all required keys are present' do
      args = { a: 1, b: 2 }
      expect { validate_args!(args, %i[a b]) }.not_to raise_error
    end

    it 'exits when required keys are missing' do
      args = { a: 1 }
      expect(self).to receive(:puts).with(/Missing required arguments: b/)
      expect(self).to receive(:exit).with(1)
      validate_args!(args, %i[a b])
    end
  end

  describe '#normalize_path' do
    it 'returns the path as-is if absolute' do
      expect(normalize_path('/tmp/foo')).to eq('/tmp/foo')
    end

    it 'joins with Rails.root if relative' do
      expect(normalize_path('relative/path')).to eq('/app/relative/path')
    end
  end

  describe '#retrieve_tracker_json' do
    let(:tracker_filename) { 'tracker.json' }

    before do
      stub_const('Tasks::IngestHelperUtils::BaseIngestTracker::TRACKER_FILENAME', tracker_filename)
    end

    it 'returns parsed JSON when tracker exists' do
      tracker_path = File.join(base_dir, tracker_filename)
      File.write(tracker_path, '{"status":"ok"}')
      expect(JsonFileUtilsHelper).to receive(:read_json).with(tracker_path).and_return({ 'status' => 'ok' })
      result = retrieve_tracker_json(base_dir)
      expect(result['status']).to eq('ok')
    end

    it 'exits if tracker file missing' do
      missing_dir = File.join(base_dir, 'missing_tracker_dir')
      FileUtils.mkdir_p(missing_dir)

      expect(self).to receive(:puts).with(/Tracker file not found/)
      expect(self).to receive(:exit).with(1)

      retrieve_tracker_json(missing_dir)
    end
  end


  describe '#resolve_output_directory' do
    context 'when resume is true' do
      it 'calls resolve_resume_directory' do
        args = { output_dir: base_dir, resume: 'true' }
        expect(self).to receive(:resolve_resume_directory).with(base_dir, 'backlog_ingest').and_return('/resolved')
        expect(resolve_output_directory(args, time)).to eq('/resolved')
      end
    end

    context 'when resume is false' do
      it 'creates a new directory' do
        args = { output_dir: base_dir, resume: false }
        expect(FileUtils).to receive(:mkdir_p).and_call_original
        result = resolve_output_directory(args, time, prefix: 'backlog_ingest')
        expect(result).to match(%r{#{base_dir}/backlog_ingest_\d{8}_\d{6}})
      end
    end
  end

  describe '#write_intro_banner' do
    let(:config) do
      {
        'resume' => false,
        'start_time' => time,
        'output_dir' => '/tmp/out',
        'full_text_dir' => '/tmp/full_text',
        'depositor_onyen' => 'dcam',
        'admin_set_title' => 'Admin Set'
      }
    end

    it 'prints and logs expected banner lines' do
      expect(self).to receive(:puts).at_least(:once)
      expect(Rails.logger).to receive(:info).at_least(:once)
      write_intro_banner(config: config, ingest_type: 'PubMed')
    end

    it 'includes additional fields when provided' do
      config['csv_path'] = '/tmp/file.csv'
      allow(self).to receive(:puts)
      write_intro_banner(config: config, ingest_type: 'NSF', additional_fields: { 'File Info CSV' => 'csv_path' })
      expect(self).to have_received(:puts).with(/file\.csv/).at_least(:once)
    end
  end

  describe 'private helpers' do
    describe '#resolve_resume_directory' do
      let(:prefix) { 'backlog_ingest' }

      it 'resolves directory pattern and logs latest match' do
        dir1 = File.join(base_dir, "#{prefix}_20241101_120000")
        dir2 = File.join(base_dir, "#{prefix}_20241102_120000")
        FileUtils.mkdir_p(dir1)
        FileUtils.mkdir_p(dir2)
        File.utime(Time.now - 60, Time.now - 60, dir1)
        File.utime(Time.now, Time.now, dir2)

        allow(LogUtilsHelper).to receive(:double_log)
        result = send(:resolve_resume_directory, "#{base_dir}/*", prefix)
        expect(result).to eq(File.expand_path(dir2))
      end

      it 'exits if no matching directories found' do
        allow(Dir).to receive(:glob).and_return([])
        allow(self).to receive(:puts)
        allow(self).to receive(:exit) { |code| throw(:exit_called, code) }

        code = catch(:exit_called) { send(:resolve_resume_directory, "#{base_dir}/nonexistent_*", 'backlog_ingest') }
        expect(self).to have_received(:puts).with(/No matching ingest directories/)
        expect(code).to eq(1)
      end

      it 'exits if directory missing' do
        missing_dir = File.join(base_dir, 'backlog_ingest_20241101_000000')
        expect(self).to receive(:puts).with(/does not exist/)
        expect(self).to receive(:exit).with(1)
        catch(:exit_called) { send(:resolve_resume_directory, missing_dir, 'backlog_ingest') }
      end

      it 'exits if basename invalid' do
        dir = File.join(base_dir, 'wrong_name')
        FileUtils.mkdir_p(dir)
        expect(self).to receive(:puts).with(/must match/)
        expect(self).to receive(:exit).with(1)
        send(:resolve_resume_directory, dir, 'backlog_ingest')
      end
    end

    describe '#create_new_output_directory' do
      it 'creates a timestamped directory' do
        result = send(:create_new_output_directory, base_dir, time, 'backlog_ingest')
        expect(result).to match(%r{#{base_dir}/backlog_ingest_\d{8}_\d{6}})
        expect(Dir.exist?(result)).to be true
      end
    end
  end
end
