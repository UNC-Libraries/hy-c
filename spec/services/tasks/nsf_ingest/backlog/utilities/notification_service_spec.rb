# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::NSFIngest::Backlog::Utilities::NotificationService, type: :service do
  let(:tracker) { { 'depositor_onyen' => 'test-user' } }
  let(:config) { { 'file_info_csv_path' => '/tmp/file_info.csv' } }
  let(:service) { described_class.new(config: config, tracker: tracker, output_dir: '/tmp/output', file_attachment_results_path: '/tmp/results.jsonl', max_display_rows: 50) }

  before do
    allow(CSV).to receive(:read).and_return([%w[doi filename], ['10.1/a', 'f1.pdf'], ['10.2/b', 'f2.pdf']])
    allow(NSFReportMailer).to receive(:nsf_report_email).and_return(double(deliver_now: true))
  end

  describe '#source_name' do
    it 'returns NSF' do
      expect(service.send(:source_name)).to eq('NSF')
    end
  end

  describe '#populate_headers!' do
    let(:report) { { headers: {} } }

    before do
      allow(service).to receive(:calculate_rows_in_csv).and_return(5)
    end

    it 'adds depositor and total file count to report headers' do
      service.send(:populate_headers!, report)
      expect(report[:headers][:depositor]).to eq('test-user')
      expect(report[:headers][:total_files]).to eq(5)
    end
  end

  describe '#send_mail' do
    let(:report) { { headers: { depositor: 'test-user' }, categories: {}, records: [] } }
    let(:zip_path) { '/tmp/nsf_results.zip' }

    it 'invokes NSFReportMailer with correct args and delivers email' do
      mail_double = double(deliver_now: true)
      expect(NSFReportMailer).to receive(:nsf_report_email)
        .with(report: report, zip_path: zip_path)
        .and_return(mail_double)

      expect(mail_double).to receive(:deliver_now)
      service.send(:send_mail, report, zip_path)
    end
  end
end
