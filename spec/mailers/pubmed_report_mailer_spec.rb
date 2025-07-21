# frozen_string_literal: true
require 'rails_helper'

RSpec.describe PubmedReportMailer, type: :mailer do
  describe 'pubmed_report_email' do
    let(:fixture_path) do
      Rails.root.join('spec', 'fixtures', 'files', 'pubmed_ingest_test_fixture.json')
    end

    let(:ingest_output) { JSON.parse(File.read(fixture_path), symbolize_names: true) }

    let(:report) { Tasks::PubmedIngest::SharedUtilities::PubmedReportingService.generate_report(ingest_output) }

    let(:mail) { described_class.pubmed_report_email(report) }

    it 'renders the headers' do
      expect(mail.subject).to eq(report[:subject])
      expect(mail.to).to eq(['cdr@unc.edu'])
      expect(mail.from).to eq(['no-reply@unc.edu'])
    end

    it 'renders the body' do
      formatted_time = Time.parse(ingest_output[:time]).strftime('%B %d, %Y at %I:%M %p %Z')

      reporting_msg          = "Reporting publications from Pubmed Ingest on <strong>#{formatted_time}</strong>"
      depositor_msg          = "<strong>Depositor: </strong>#{report[:headers][:depositor]}"
      total_unique_files_msg = "<strong>Total Unique Files: </strong>#{report[:headers][:total_unique_files]}"

      expect(mail.body.encoded).to include(reporting_msg)
                                  .and include(depositor_msg)
                                  .and include(total_unique_files_msg)

      report[:records].each do |category, records|
        records.each do |record|
          expect(mail.body.encoded).to include(record[:file_name].to_s)
                                      .and include(record[:cdr_url] || 'NONE')
                                      .and include(record[:pdf_attached])
                                      .and include(record[:pmid] || 'NONE')
                                      .and include(record[:pmcid] || 'NONE')
                                      .and include(record[:doi] || 'NONE')
        end
      end
    end
  end
end
