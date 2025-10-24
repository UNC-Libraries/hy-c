# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::PubmedIngest::Recurring::Utilities::NotificationService, type: :service do
  let(:tracker) do
    {
      'depositor_onyen' => 'admin',
      'date_range' => { 'start' => '2025-01-01', 'end' => '2025-02-01' },
      'progress' => {
        'adjust_id_lists' => {
          'pubmed' => { 'adjusted_size' => 3 },
          'pmc'    => { 'adjusted_size' => 2 }
        }
      }
    }.with_indifferent_access
  end

  let(:config) { { 'depositor_onyen' => 'admin' } }
  let(:output_dir) { '/tmp/output' }
  let(:results_path) { '/tmp/results.jsonl' }

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
    allow(PubmedReportMailer).to receive(:pubmed_report_email)
      .and_return(double('Mail::Message', deliver_now: true))
  end

  describe '#source_name' do
    it 'returns "PubMed"' do
      expect(service.send(:source_name)).to eq('PubMed')
    end
  end

  describe '#populate_headers!' do
    it 'fills report headers with depositor, totals, and formatted dates' do
      report = { headers: {} }

      service.send(:populate_headers!, report)

      expect(report[:headers][:depositor]).to eq('admin')
      expect(report[:headers][:total_unique_records]).to eq(5)
      expect(report[:headers][:start_date]).to eq('2025-01-01')
      expect(report[:headers][:end_date]).to eq('2025-02-01')
    end
  end

  describe '#send_mail' do
    it 'sends a PubMed report email with report and zip path' do
      report = { headers: { depositor: 'admin' } }
      zip_path = '/tmp/pubmed_results.zip'

      service.send(:send_mail, report, zip_path)

      expect(PubmedReportMailer).to have_received(:pubmed_report_email)
        .with(report: report, zip_path: zip_path)
    end

    it 'calls deliver_now on the mailer message' do
      mail_double = double('Mail::Message')
      allow(mail_double).to receive(:deliver_now)
      allow(PubmedReportMailer).to receive(:pubmed_report_email).and_return(mail_double)

      report = { headers: {} }
      service.send(:send_mail, report, '/tmp/file.zip')

      expect(mail_double).to have_received(:deliver_now)
    end
  end
end
