# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::DimensionsReportingService do
  let(:config) {
    {
      'admin_set' => 'Open_Access_Articles_and_Book_Chapters',
      'depositor_onyen' => 'admin'
    }
  }
  let(:service) { described_class.new(ingested_publications) }
  let(:dimensions_ingest_test_fixture) do
    File.read(File.join(Rails.root, '/spec/fixtures/files/dimensions_ingest_test_fixture.json'))
  end
  let(:admin) { FactoryBot.create(:admin) }
  let(:ingest_service) { Tasks::DimensionsIngestService.new(config) }
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
  let(:test_publications) { JSON.parse(dimensions_ingest_test_fixture)['publications'] }
  let(:failing_publication_sample) { test_publications[0..2] }
  let(:successful_publication_sample) { test_publications[6..-1] }
  let(:marked_for_review_sample) do
    test_publications[3..5].each { |pub| pub['marked_for_review'] = true }
    test_publications[3..5]
  end
  let(:ingested_publications) do
    ingest_service.ingest_publications(test_publications)
  end
  


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
    marked_for_review_sample
    ingested_publications
    # stub virus checking
    allow(Hyrax::VirusCheckerService).to receive(:file_has_virus?) { false }
    # stub longleaf job
    allow(RegisterToLongleafJob).to receive(:perform_later).and_return(nil)
    # stub FITS characterization
    allow(CharacterizeJob).to receive(:perform_later)
  end

  describe '#generate_report' do
    it 'generates a report for ingest dimensions publications' do
      report = service.generate_report
      expect(report).to include("Reporting publications from dimensions ingest at May 21, 2024 at 10:00 AM UTC by admin.")
                    .and include("Admin Set: Open_Access_Articles_and_Book_Chapters")
                    .and include("Total Publications: #{test_publications.length}")
                    .and include("Successfully Ingested: (#{successful_publication_sample.length} Publications)")
                    .and include("Marked for Review: (#{marked_for_review_sample.length} Publications)")
                    .and include("Failed to Ingest: (#{failing_publication_sample.length} Publications)")
    end
  end
  
  describe '#extract_publication_info' do
    def expect_publication_info(info_array, sample_array, failed)
        info_array.each_with_index do |info, i|
        expect(info).to include("Title: #{sample_array[i]['title']}")
        expect(info).to include("ID: #{sample_array[i]['id']}")
        expect(info).to include("URL: https://cdr.lib.unc.edu/concern/articles/#{sample_array[i]['article_id']}?locale=en") if !failed
        expect(info).to include("Error: StandardError - #{test_err_msg}") if failed
        end
    end

    it 'extracts publication information for the report' do
        extracted_info = service.extract_publication_info
        expect(extracted_info[:successfully_ingested].length).to eq(4)
        expect(extracted_info[:marked_for_review].length).to eq(3)
        expect(extracted_info[:failed_to_ingest].length).to eq(3)
    
        expect_publication_info(extracted_info[:successfully_ingested], ingested_publications[:ingested].select { |pub| !pub['marked_for_review'] }, false)
        expect_publication_info(extracted_info[:marked_for_review], ingested_publications[:ingested].select { |pub| pub['marked_for_review'] }, false)
        expect_publication_info(extracted_info[:failed_to_ingest], ingested_publications[:failed], true)
    end
  end
end