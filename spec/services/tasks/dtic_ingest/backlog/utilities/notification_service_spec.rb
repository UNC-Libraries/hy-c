# frozen_string_literal: true
require 'rails_helper'
RSpec.describe Tasks::DTICIngest::Backlog::Utilities::NotificationService do
  let (:admin_set) { FactoryBot.create(:admin_set) }
  let (:config) do
    {
        'start_time' => DateTime.new(2024, 1, 1),
        'restart_time' => nil,
        'resume' => false,
        'admin_set_title' => admin_set.title,
        'depositor_onyen' => 'testuser',
        'output_dir' => '/tmp/dtic_output',
        'full_text_dir' => '/tmp/dtic_full_text'
    }
  end
  let(:tracker) { { 'depositor_onyen' => 'testuser' } }
  subject(:service) { described_class.new(config: config,
                      tracker: tracker,
                      output_dir: '/tmp/dtic_output',
                      file_attachment_results_path: '/tmp/dtic_file_attachment_results.csv')
  }

  describe '#populate_headers!' do
    it 'populates the report headers correctly' do
      report = {
          headers: { total_files: 0 },
          records: {
          success: [
              { 'ids' => { 'dtic_id' => '123456' }, 'file_name' => 'file1.pdf' },
              { 'ids' => { 'dtic_id' => '654321' }, 'file_name' => 'file2.pdf' },
          ],
          failure: [
              { 'ids' => { 'dtic_id' => '000000' }, 'file_name' => 'file3.pdf' }
          ]
          }
      }

      service.send(:populate_headers!, report)

      expect(report[:headers][:depositor]).to eq('testuser')
      expect(report[:headers][:total_files]).to eq(3)
    end
  end

  describe '#send_mail' do
    it 'sends an email using DTICReportMailer' do
      report = { headers: {}, records: {} }
      zip_path = '/path/to/report.zip'

      mailer_double = double('Mailer', deliver_now: true)
      allow(DTICReportMailer).to receive(:dtic_report_email).with(report: report, zip_path: zip_path).and_return(mailer_double)

      service.send(:send_mail, report, zip_path)

      expect(DTICReportMailer).to have_received(:dtic_report_email).with(report: report, zip_path: zip_path)
      expect(mailer_double).to have_received(:deliver_now)
    end
  end
end
