# frozen_string_literal: true
# spec/mailers/dimensions_report_mailer_spec.rb
require 'rails_helper'

RSpec.describe DimensionsReportMailer, type: :mailer do
  TEST_START_DATE = '1970-01-01'
  TEST_END_DATE = '2021-01-01'
  FIXED_DIMENSIONS_TOTAL_COUNT = 2974

  let(:config) {
    {
      'admin_set' => 'Open_Access_Articles_and_Book_Chapters',
      'depositor_onyen' => ENV['DIMENSIONS_INGEST_DEPOSITOR_ONYEN']
    }
  }
  let(:dimensions_ingest_test_fixture) do
    File.read(File.join(Rails.root, '/spec/fixtures/files/dimensions_ingest_test_fixture.json'))
  end

  let(:admin) { FactoryBot.create(:admin, uid: 'admin') }
  let(:admin_set) do
    FactoryBot.create(:admin_set, title: ['Open_Access_Articles_and_Book_Chapters'])
  end
  let(:permission_template) do
    FactoryBot.create(:permission_template, source_id: admin_set.id)
  end
  let(:workflow) do
    FactoryBot.create(:workflow, permission_template_id: permission_template.id, active: true)
  end
  let(:workflow_state) do
    FactoryBot.create(:workflow_state, workflow_id: workflow.id, name: 'deposited')
  end

  let(:pdf_content) { File.binread(File.join(Rails.root, '/spec/fixtures/files/sample_pdf.pdf')) }
  let(:test_err_msg) { 'Test error' }

  let(:fixed_time) { Time.new(2024, 5, 21, 10, 0, 0) }
  # Removing linkout pdf from some publications to simulate missing pdfs
  let(:test_publications) {
    all_publications =  JSON.parse(dimensions_ingest_test_fixture)['publications']
    all_publications.each_with_index do |pub, index|
      pub.delete('linkout') if index.even?
    end
    all_publications
  }

  let(:failing_publication_sample) { test_publications[0..2] }

  let(:ingest_service) { Tasks::DimensionsIngestService.new(config) }
  let(:ingested_publications) do
    ingest_service.ingest_publications(test_publications)
  end
  let(:report) { Tasks::DimensionsReportingService.new(ingested_publications, FIXED_DIMENSIONS_TOTAL_COUNT, { start_date: TEST_START_DATE, end_date: TEST_END_DATE }, FALSE).generate_report }

  before do
    ActiveFedora::Cleaner.clean!
    admin_set
    permission_template
    workflow
    workflow_state
    allow(Time).to receive(:now).and_return(fixed_time)
    allow(User).to receive(:find_by).with(uid: 'admin').and_return(admin)
    allow(AdminSet).to receive(:where).with(title: 'Open_Access_Articles_and_Book_Chapters').and_return([admin_set])
    stub_request(:head, 'https://test-url.com/')
      .to_return(status: 200, headers: { 'Content-Type' => 'application/pdf' })
    stub_request(:get, 'https://test-url.com/')
      .to_return(body: pdf_content, status: 200, headers: { 'Content-Type' => 'application/pdf' })
    allow(ingest_service).to receive(:process_publication).and_call_original
    allow(ingest_service).to receive(:process_publication).with(satisfy { |pub| failing_publication_sample.include?(pub) }).and_raise(StandardError, test_err_msg)
    # stub virus checking
    allow(Hyrax::VirusCheckerService).to receive(:file_has_virus?) { false }
    # stub longleaf job
    allow(RegisterToLongleafJob).to receive(:perform_later).and_return(nil)
    # stub FITS characterization
    allow(CharacterizeJob).to receive(:perform_later)
    ingested_publications
  end

  # Override the depositor onyen for the duration of the test
  around do |example|
    dimensions_ingest_depositor_onyen = ENV['DIMENSIONS_INGEST_DEPOSITOR_ONYEN']
    ENV['DIMENSIONS_INGEST_DEPOSITOR_ONYEN'] = 'admin'
    example.run
    ENV['DIMENSIONS_INGEST_DEPOSITOR_ONYEN'] = dimensions_ingest_depositor_onyen
  end

  describe 'dimensions_report_email' do
    let(:mail) { DimensionsReportMailer.dimensions_report_email(report) }

    it 'renders the headers' do
      expect(mail.subject).to eq(report[:subject])
      expect(mail.to).to eq(['cdr@unc.edu'])
      expect(mail.from).to eq(['no-reply@unc.edu'])
    end

    it 'renders the body' do
      expect(mail.body.encoded).to include(report[:headers][:reporting_message])
                                .and include(report[:headers][:admin_set])
                                .and include(report[:headers][:unique_publications])
                                .and include(report[:headers][:successfully_ingested])
                                .and include(report[:headers][:failed_to_ingest])

      report[:successfully_ingested_rows].each do |publication|
        expect(mail.body.encoded).to include(publication[:title])
                                .and include(publication[:id])
                                .and include(publication[:url])
                                .and include(publication[:pdf_attached])
      end
      report[:failed_to_ingest_rows].each do |publication|
        expect(mail.body.encoded).to include(publication[:title])
                                 .and include(publication[:id])
                                 .and include(publication[:error])
      end
    end

    it 'renders a different message for manually executed ingest' do
      service = Tasks::DimensionsReportingService.new(ingested_publications, FIXED_DIMENSIONS_TOTAL_COUNT, { start_date: TEST_START_DATE, end_date: TEST_END_DATE }, FALSE)
      report = service.generate_report
      mail = DimensionsReportMailer.dimensions_report_email(report)
      expect(mail.body.encoded).to include('Reporting publications from manually executed Dimensions ingest')
    end
  end
end
