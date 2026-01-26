# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::NoaaIngest::Backlog::Utilities::NotificationService do
  let(:admin_set) { FactoryBot.create(:admin_set, title: ['Noaa Admin Set']) }
  let(:config) do
    {
      'start_time' => DateTime.new(2024, 1, 1),
      'restart_time' => nil,
      'resume' => false,
      'admin_set_title' => admin_set.title.first,
      'depositor_onyen' => 'testuser',
      'output_dir' => '/tmp/noaa_output',
      'full_text_dir' => '/tmp/noaa_full_text'
    }
  end
  let(:tracker) { { 'depositor_onyen' => 'testuser', 'admin_set_title' => admin_set.title.first } }

  subject(:service) do
    described_class.new(
      config: config,
      tracker: tracker,
      output_dir: '/tmp/noaa_output',
      file_attachment_results_path: '/tmp/noaa_file_attachment_results.jsonl'
    )
  end

  describe '#populate_headers!' do
    it 'populates the report headers correctly' do
      allow(service).to receive(:noaa_pdf_count).and_return(5)
      report = {
        headers: { total_files: 0 },
        records: {
          successfully_ingested_and_attached: [
            { 'ids' => { 'noaa_id' => '79129' } },
            { 'ids' => { 'noaa_id' => '140512' } }
          ],
          failed: [
            { 'ids' => { 'noaa_id' => '999999' } }
          ]
        }
      }

      service.send(:populate_headers!, report)

      expect(report[:headers][:depositor]).to eq('testuser')
      expect(report[:headers][:admin_set_title]).to eq(admin_set.title.first)
      expect(report[:headers][:total_files]).to eq(5)
    end
  end

  describe '#send_mail' do
    it 'sends an email using NoaaReportMailer' do
      report = { headers: {}, records: {} }
      zip_path = '/path/to/noaa_report.zip'

      mailer_double = double('Mailer', deliver_now: true)
      allow(NoaaReportMailer).to receive(:report_email).with(report: report, zip_path: zip_path).and_return(mailer_double)

      service.send(:send_mail, report, zip_path)

      expect(NoaaReportMailer).to have_received(:report_email).with(report: report, zip_path: zip_path)
      expect(mailer_double).to have_received(:deliver_now)
    end
  end
end
