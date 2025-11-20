# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::IngestHelperUtils::BaseIngestNotificationService, type: :service do
  let(:config) { { 'depositor_onyen' => 'admin' } }
  let(:progress_hash) do
    {
      'progress' => {
        'send_summary_email' => {
          'completed' => false
        },
        'prepare_email_attachments' => {
          'completed' => false
      }
    }
    }
  end
  let(:tracker) do
    double(
      'Tracker',
      '[]' => progress_hash['progress'],
      :save => true
    ).tap do |t|
      # Allow nested hash access
      allow(t).to receive(:[]).with('progress').and_return(progress_hash['progress'])
      allow(t).to receive(:[]=)
    end
  end
  let(:output_dir) { '/tmp/output' }
  let(:results_path) { '/tmp/attachment_results.jsonl' }

  subject(:service) do
    described_class.new(
      config: config,
      tracker: tracker,
      output_dir: output_dir,
      file_attachment_results_path: results_path,
      max_display_rows: 50
    )
  end

  before do
    # Stub helpers that would normally perform I/O or reporting
    allow(LogUtilsHelper).to receive(:double_log)
    allow(Tasks::IngestHelperUtils::IngestReportingService)
      .to receive(:generate_report)
      .and_return({ ingest_output: { counts: { total_files: 2 } }, records: [], headers: {} })

    # Stub methods from ReportingHelper module
    allow(service).to receive(:load_results).and_return({ some: 'results' })
    allow(service).to receive(:generate_truncated_categories).and_return({})
    allow(service).to receive(:generate_result_csvs).and_return(['/tmp/file1.csv'])
    allow(service).to receive(:compress_result_csvs).and_return('/tmp/results.zip')

    # Stub abstract methods
    allow(service).to receive(:populate_headers!)
    allow(service).to receive(:source_name).and_return('TestSource')
    allow(service).to receive(:send_mail)
  end

  describe '#initialize' do
    it 'sets instance variables correctly' do
      expect(service.instance_variable_get(:@config)).to eq(config)
      expect(service.instance_variable_get(:@tracker)).to eq(tracker)
      expect(service.instance_variable_get(:@output_dir)).to eq(output_dir)
      expect(service.instance_variable_get(:@file_attachment_results_path)).to eq(results_path)
      expect(service.instance_variable_get(:@max_display_rows)).to eq(50)
    end
  end

  describe '#run' do
    it 'loads results and sends summary email' do
      expect(service).to receive(:load_results).with(path: results_path, tracker: tracker)
      expect(service).to receive(:send_summary_email).with({ some: 'results' })
      service.run
    end
  end

  describe '#send_summary_email' do
    it 'generates report and sends email successfully' do
      expect(service).to receive(:send_mail).with(kind_of(Hash), '/tmp/results.zip')
      service.send(:send_summary_email, { test: 'data' })

      expect(LogUtilsHelper).to have_received(:double_log).with(
        'Finalizing report and sending notification email...',
        :info,
        tag: 'send_summary_email'
      )
      expect(LogUtilsHelper).to have_received(:double_log).with(
        'Email notification sent successfully.',
        :info,
        tag: 'send_summary_email'
      )
    end

    it 'marks tracker as completed after sending' do
      service.send(:send_summary_email, { test: 'data' })
      expect(progress_hash['progress']['send_summary_email']['completed']).to be true
    end

    it 'skips if already sent' do
      progress_hash['progress']['send_summary_email']['completed'] = true
      expect(service).not_to receive(:send_mail)
      service.send(:send_summary_email, { test: 'data' })
    end
  end

  describe '#already_sent?' do
    it 'returns true and logs when already sent' do
      progress_hash['progress']['send_summary_email']['completed'] = true
      result = service.send(:already_sent?)
      expect(result).to be true
      expect(LogUtilsHelper).to have_received(:double_log).with(
        'Skipping email notification as it has already been sent.',
        :info,
        tag: 'send_summary_email'
      )
    end

    it 'returns false when not sent' do
      progress_hash['progress']['send_summary_email']['completed'] = false
      expect(service.send(:already_sent?)).to be false
    end
  end

  describe '#mark_as_sent!' do
    it 'updates tracker and saves' do
      service.send(:mark_as_sent!)
      expect(progress_hash['progress']['send_summary_email']['completed']).to be true
      expect(tracker).to have_received(:save)
    end
  end

  describe '#category_labels' do
    it 'returns a hash of category label mappings' do
      labels = service.send(:category_labels)
      expect(labels[:successfully_ingested_and_attached]).to eq('Successfully Ingested and Attached')
      expect(labels[:failed]).to eq('Failed')
      expect(labels[:skipped_non_unc_affiliation]).to eq('Skipped (No UNC Affiliation)')
    end
  end

  describe '#calculate_rows_in_csv' do
    it 'returns row count when file exists' do
      allow(File).to receive(:exist?).and_return(true)
      allow(CSV).to receive(:read).and_return([%w[a b], %w[c d]])
      expect(service.send(:calculate_rows_in_csv, '/tmp/file.csv')).to eq(2)
    end

    it 'returns 0 when file does not exist' do
      allow(File).to receive(:exist?).and_return(false)
      expect(service.send(:calculate_rows_in_csv, '/tmp/missing.csv')).to eq(0)
    end
  end

  describe 'abstract methods' do
    # Remove the stub for these tests to verify NotImplementedError is raised
    before do
      allow(service).to receive(:source_name).and_call_original
      allow(service).to receive(:populate_headers!).and_call_original
      allow(service).to receive(:send_mail).and_call_original
    end

    it 'raises NotImplementedError for #source_name' do
      expect { service.send(:source_name) }.to raise_error(NotImplementedError)
    end

    it 'raises NotImplementedError for #populate_headers!' do
      expect { service.send(:populate_headers!, {}) }.to raise_error(NotImplementedError)
    end

    it 'raises NotImplementedError for #send_mail' do
      expect { service.send(:send_mail, {}, '/tmp/file.zip') }.to raise_error(NotImplementedError)
    end
  end
end
