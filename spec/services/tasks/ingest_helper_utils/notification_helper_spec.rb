# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::IngestHelperUtils::NotificationHelper, type: :helper do
  let(:results) { [{ id: 1, status: 'ok' }, { id: 2, status: 'fail' }] }
  let(:csv_output_dir) { '/tmp/csv_output' }

  let(:tracker_hash) do
    {
      'depositor_onyen' => 'admin',
      'date_range' => { 'start' => '2025-01-01', 'end' => '2025-02-01' },
      'progress' => {
        'send_summary_email' => { 'completed' => false },
        'adjust_id_lists' => {
          'pubmed' => { 'adjusted_size' => 3 },
          'pmc' => { 'adjusted_size' => 2 }
        }
      }
    }.with_indifferent_access
  end

  let(:tracker) do
    double('Tracker', save: true).tap do |t|
      # Allow hash-like access
      allow(t).to receive(:[]) { |key| tracker_hash[key] }
      allow(t).to receive(:[]=) { |key, value| tracker_hash[key] = value }
      allow(t).to receive(:dig) do |*keys|
        keys.reduce(tracker_hash) { |acc, k| acc[k] if acc }
      end
    end
  end

  let(:mailer) { double('Mailer') }

  before do
    allow(LogUtilsHelper).to receive(:double_log)

    # Stub the correct service class methods (not ReportingHelper)
    allow(Tasks::IngestHelperUtils::ReportingHelper).to receive(:generate_result_csvs)
      .and_return(['/tmp/file1.csv', '/tmp/file2.csv'])
    allow(Tasks::IngestHelperUtils::ReportingHelper).to receive(:compress_result_csvs)
      .and_return('/tmp/results.zip')

    email_double = double('Mail::Message', deliver_now: true)
    allow(mailer).to receive(:pubmed_report_email).and_return(email_double)
    allow(Rails.logger).to receive(:error)
  end

  describe '.send_report_and_notify' do
    it 'generates CSVs, compresses them, builds report, sends email, and marks tracker complete' do
      described_class.send_report_and_notify(
        results: results, tracker: tracker, csv_output_dir: csv_output_dir, mailer: mailer
      )

      expect(Tasks::IngestHelperUtils::ReportingHelper).to have_received(:generate_result_csvs)
        .with(results: results, csv_output_dir: csv_output_dir)
      expect(Tasks::IngestHelperUtils::ReportingHelper).to have_received(:compress_result_csvs)
        .with(csv_paths: ['/tmp/file1.csv', '/tmp/file2.csv'], zip_output_dir: csv_output_dir)
      expect(mailer).to have_received(:pubmed_report_email)
        .with(hash_including(:report, :zip_path))
      expect(tracker_hash['progress']['send_summary_email']['completed']).to be true
      expect(tracker).to have_received(:save)
      expect(LogUtilsHelper).to have_received(:double_log)
        .with('Email notification sent successfully.', :info, tag: 'send_summary_email')
    end

    it 'skips if already completed' do
      tracker_hash['progress']['send_summary_email']['completed'] = true
      expect(Tasks::IngestHelperUtils::ReportingHelper).not_to receive(:generate_result_csvs)

      described_class.send_report_and_notify(
        results: results, tracker: tracker, csv_output_dir: csv_output_dir, mailer: mailer
      )
    end

    it 'logs error if mail sending fails' do
      allow(mailer).to receive(:pubmed_report_email).and_raise(StandardError, 'SMTP boom')

      described_class.send_report_and_notify(
        results: results, tracker: tracker, csv_output_dir: csv_output_dir, mailer: mailer
      )

      expect(LogUtilsHelper).to have_received(:double_log).with(
        'Failed to send email notification: SMTP boom',
        :error,
        tag: 'send_summary_email'
      )
      expect(Rails.logger).to have_received(:error)
    end
  end

  describe '.build_report' do
    it 'returns structured report with headers, categories, and records' do
      report = described_class.build_report(results: results, tracker: tracker)

      expect(report[:headers][:depositor]).to eq('admin')
      expect(report[:headers][:total_unique_records]).to eq(5)
      expect(report[:headers][:start_date]).to eq('2025-01-01')
      expect(report[:headers][:end_date]).to eq('2025-02-01')

      expect(report[:categories][:failed]).to eq('Failed')
      expect(report[:records]).to eq(results)
    end
  end
end
