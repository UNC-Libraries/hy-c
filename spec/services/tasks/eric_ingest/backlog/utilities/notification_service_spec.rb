# frozen_string_literal: true
require 'rails_helper'
RSpec.describe Tasks::EricIngest::Backlog::Utilities::NotificationService do
  let (:admin_set) { FactoryBot.create(:admin_set) }
  let (:config) do
    {
        'start_time' => DateTime.new(2024, 1, 1),
        'restart_time' => nil,
        'resume' => false,
        'admin_set_title' => admin_set.title,
        'depositor_onyen' => 'testuser',
        'output_dir' => '/tmp/eric_output',
        'full_text_dir' => '/tmp/eric_full_text'
    }
  end
  let(:tracker) { { 'depositor_onyen' => 'testuser' } }
  subject(:service) { described_class.new(config: config,
                      tracker: tracker,
                      output_dir: '/tmp/eric_output',
                      file_attachment_results_path: '/tmp/eric_file_attachment_results.csv')
  }

  describe '#populate_headers!' do
    it 'populates the report headers correctly' do
      allow(service).to receive(:eric_pdf_count).and_return(3)
      report = {
          headers: { total_files: 0 },
          records: {
          success: [
              { 'ids' => { 'eric_id' => 'ED123456' } },
              { 'ids' => { 'eric_id' => 'ED654321' } }
          ],
          failure: [
              { 'ids' => { 'eric_id' => 'ED000000' } }
          ]
          }
      }

      service.send(:populate_headers!, report)

      expect(report[:headers][:depositor]).to eq('testuser')
      expect(report[:headers][:total_files]).to eq(3)
    end
  end

  describe '#send_mail' do
    it 'sends an email using ERICReportMailer' do
      report = { headers: {}, records: {} }
      zip_path = '/path/to/report.zip'

      mailer_double = double('Mailer', deliver_now: true)
      allow(ERICReportMailer).to receive(:eric_report_email).with(report: report, zip_path: zip_path).and_return(mailer_double)

      service.send(:send_mail, report, zip_path)

      expect(ERICReportMailer).to have_received(:eric_report_email).with(report: report, zip_path: zip_path)
      expect(mailer_double).to have_received(:deliver_now)
    end
  end
end
