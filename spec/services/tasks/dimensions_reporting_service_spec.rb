# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::DimensionsReportingService do
  TEST_START_DATE = '1970-01-01'
  TEST_END_DATE = '2021-01-01'
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
  let(:fixed_dimensions_total_count) { 2974 }

  let(:fixed_time) { Time.new(2024, 5, 21, 10, 0, 0) }
  # Removing linkout pdf from some publications to simulate missing pdfs
  let(:test_publications) {
    all_publications =  JSON.parse(dimensions_ingest_test_fixture)['publications']
    all_publications.each_with_index do |pub, index|
      pub.delete('linkout') if index.even?
    end
    all_publications
  }
  let(:failing_publication_sample) {
    { publications: test_publications[0..2], test_fixture_start_index: 0 }
  }
  let(:successful_publication_sample) {
    { publications: test_publications[3..-1], test_fixture_start_index: 3 }
  }
  let(:ingest_service) { Tasks::DimensionsIngestService.new(config) }
  let(:ingested_publications) do
    ingest_service.ingest_publications(test_publications)
  end

  let(:service) { described_class.new(ingested_publications, fixed_dimensions_total_count, TEST_START_DATE, TEST_END_DATE, TRUE) }


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
    allow(ingest_service).to receive(:process_publication).with(satisfy { |pub| failing_publication_sample[:publications].include?(pub) }).and_raise(StandardError, test_err_msg)
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

  describe '#generate_report' do
    it 'generates a report for ingest dimensions publications' do
      report = service.generate_report
      headers = report[:headers]
      expect(report[:subject]).to eq('Dimensions Ingest Report for May 21, 2024 at 10:00 AM UTC')
      expect(headers[:reporting_message]).to eq('Reporting publications from automated dimensions ingest on May 21, 2024 at 10:00 AM UTC by admin.')
      expect(headers[:date_range]).to eq("Publication Date Range: #{TEST_START_DATE} to #{TEST_END_DATE}")
      expect(headers[:admin_set]).to eq('Admin Set: Open_Access_Articles_and_Book_Chapters')
      expect(headers[:unique_publications]).to eq("Attempted to ingest #{test_publications.length} unique publications out of #{fixed_dimensions_total_count} total publications found in Dimensions.")
      expect(headers[:successfully_ingested]).to eq("\nSuccessfully Ingested: (#{successful_publication_sample[:publications].length} Publications)")
      expect(headers[:failed_to_ingest]).to eq("\nFailed to Ingest: (#{failing_publication_sample[:publications].length} Publications)")
    end

    it 'provides a different message for manually executed ingest' do
      service = described_class.new(ingested_publications, fixed_dimensions_total_count, TEST_START_DATE, TEST_END_DATE, FALSE)
      report = service.generate_report
      headers = report[:headers]
      expect(headers[:reporting_message]).to eq('Reporting publications from manually executed dimensions ingest on May 21, 2024 at 10:00 AM UTC by admin.')
    end
  end

  describe '#extract_publication_info' do
    def expect_publication_info(info_array, sample_array, failed, sample_start_index)
      info_array.each_with_index do |info, i|

        expect(info[:title]).to eq(sample_array[i]['title'])
        expect(info[:id]).to eq(sample_array[i]['id'])
        if failed
          expect(info[:error]).to eq("StandardError - #{test_err_msg}")
          expect(info[:pdf_attached]).to be_nil
        else
          expect(info[:url]).to eq("#{ENV['HYRAX_HOST']}/concern/articles/#{sample_array[i]['article_id']}?locale=en")
          # Offsetting the index if the sample start index is odd
          offset_index = sample_start_index.even? ? i : i - 1
          expect(info[:pdf_attached]).to eq('No') if offset_index.even?
          expect(info[:pdf_attached]).to eq('Yes') if offset_index.odd?
        end
      end
    end

    it 'extracts publication information for the report' do
      extracted_info = service.extract_publication_info
      expect(extracted_info[:successfully_ingested].length).to eq(7)
      expect(extracted_info[:failed_to_ingest].length).to eq(3)

      expect_publication_info(extracted_info[:successfully_ingested], ingested_publications[:ingested], false, successful_publication_sample[:test_fixture_start_index])
      expect_publication_info(extracted_info[:failed_to_ingest], ingested_publications[:failed], true, failing_publication_sample[:test_fixture_start_index])
    end
  end
end
