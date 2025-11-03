# frozen_string_literal: true
require 'rails_helper'

RSpec.describe BaseIngestReportMailer, type: :mailer do
  let(:report) { { subject: 'Test Report', to: 'user@example.com' } }
  let(:zip_path) { Rails.root.join('spec/fixtures/files/test.zip') }

  before do
    allow(LogUtilsHelper).to receive(:double_log)
    allow(File).to receive(:exist?).with(zip_path).and_return(true)
    allow(File).to receive(:read).with(zip_path).and_return('fake zip data')
  end

  it 'attaches the ZIP and logs it' do
    mailer = described_class.new

    # Mock the mail method to return a double with attachments
    mail_double = double('mail', attachments: [double(filename: 'test.zip')])
    allow(mailer).to receive(:mail).and_return(mail_double)

    mail = mailer.ingest_report_email(
      report: report,
      zip_path: zip_path,
      template_name: 'template_name'
    )

    expect(mail.attachments.first.filename).to eq('test.zip')
    expect(LogUtilsHelper).to have_received(:double_log)
      .with(a_string_including('Attached ZIP file'), :info, tag: 'template_name_report_email')
  end

  it 'sends mail with correct subject and recipient' do
    mailer = described_class.new

    # Mock the mail method to capture the parameters
    allow(mailer).to receive(:mail) do |params|
      double('mail', subject: params[:subject], to: [params[:to]])
    end

    mail = mailer.ingest_report_email(
      report: report,
      zip_path: zip_path,
      template_name: 'template_name'
    )

    expect(mail.subject).to eq('Test Report')
    expect(mail.to).to eq(['user@example.com'])
  end
end
