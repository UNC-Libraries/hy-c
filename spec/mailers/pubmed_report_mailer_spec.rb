# frozen_string_literal: true
# spec/mailers/pubmed_report_mailer_spec.rb
require 'rails_helper'

RSpec.describe PubmedReportMailer, type: :mailer do
  describe 'pubmed_report_email' do
    let(:fixture_path) do
      Rails.root.join('spec', 'fixtures', 'files', 'pubmed_ingest_test_fixture.json')
    end

    let(:ingest_output) do
      JSON.parse(File.read(fixture_path))
    end

    let(:report) { Tasks::PubmedReportingService.generate_report(ingest_output) }
    let(:mail) { described_class.pubmed_report_email(report) }

    it 'renders the headers' do
      expect(mail.subject).to eq(report[:subject])
      expect(mail.to).to eq(['cdr@unc.edu'])
      expect(mail.from).to eq(['no-reply@unc.edu'])
    end

    it 'renders the body' do
        formatted_time = Time.parse(ingest_output['time']).strftime('%B %d, %Y at %I:%M %p %Z')
        reporting_msg = "Reporting publications from Pubmed Ingest on <strong>#{formatted_time}</strong>"
        depositor_msg = "<strong>Depositor: </strong>#{report[:headers][:depositor]}"
        file_retrieval_msg = "<strong>File Retrieval Directory: </strong>\"#{report[:file_retrieval_directory]}\""
        total_unique_files_msg = "<strong>Total Unique Files: </strong>#{report[:headers][:total_unique_files]}"

        expect(mail.body.encoded).to include(reporting_msg)
                                  .and include(depositor_msg)
                                  .and include(file_retrieval_msg)
                                  .and include(total_unique_files_msg)
  
        # report[:successfully_ingested_rows].each do |publication|
        #   expect(mail.body.encoded).to include(publication[:title])
        #                           .and include(publication[:id])
        #                           .and include(publication[:url])
        #                           .and include(publication[:linkout] || 'N/A')
        #                           .and include(publication[:pdf_attached])
        # end
        # report[:failed_to_ingest_rows].each do |publication|
        #   expect(mail.body.encoded).to include(publication[:title])
        #                            .and include(publication[:id])
        #                            .and include(publication[:error])
        #                            .and include(publication[:linkout] || 'N/A')
        end
      end
    end