# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::DimensionsReportingService do
  let(:config) {
    {
      'admin_set' => 'Open_Access_Articles_and_Book_Chapters',
      'depositor_onyen' => 'admin'
    }
  }
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


  # Retrieving fixture publications and randomly assigning the marked_for_review attribute
  let(:test_publications) do
    JSON.parse(dimensions_ingest_test_fixture)['publications']
  end


  before do
    ActiveFedora::Cleaner.clean!
    admin_set
    permission_template
    workflow
    workflow_state
    allow(User).to receive(:find_by).with(uid: 'admin').and_return(admin)
    allow(AdminSet).to receive(:where).with(title: 'Open_Access_Articles_and_Book_Chapters').and_return([admin_set])
    stub_request(:head, 'https://test-url.com/')
      .to_return(status: 200, headers: { 'Content-Type' => 'application/pdf' })
    stub_request(:get, 'https://test-url.com/')
      .to_return(body: pdf_content, status: 200, headers: { 'Content-Type' => 'application/pdf' })
    # stub virus checking
    allow(Hyrax::VirusCheckerService).to receive(:file_has_virus?) { false }
    # stub longleaf job
    allow(RegisterToLongleafJob).to receive(:perform_later).and_return(nil)
    # stub FITS characterization
    allow(CharacterizeJob).to receive(:perform_later)
  end

  describe '#report' do
    it 'generates a report for ingest dimensions publications' do
    # Splitting the test publications into three groups: failing, marked_for_review, and ingested
      failing_publication_sample = test_publications[0..2]
      marked_for_review_sample = test_publications[3..5]
      marked_for_review_sample.each { |pub| pub['marked_for_review'] = true }
      ingested_publications = test_publications[5..-1]
      test_err_msg = 'Test error'
    
    #   expected_log_outputs = failing_publication_sample.flat_map do |pub|
    #     "Error ingesting publication '#{pub['title']}'",
    #     [StandardError.to_s, test_err_msg].join($RS)
    #   end
    #   expected_log_outputs = [
    #     "Error ingesting publication '#{failing_publication['title']}'",
    #     [StandardError.to_s, test_err_msg].join($RS)
    #   ]
    
      # Stub the process_publication method to raise an error for the three first publications
      allow(ingest_service).to receive(:process_publication).and_call_original
      allow(ingest_service).to receive(:process_publication).with(satisfy { |pub| failing_publication_sample.include?(pub) }).and_raise(StandardError, test_err_msg)
      
      ingested_publications = ingest_service.ingest_publications(test_publications)
      described_class.new(ingested_publications).report


    #   expected_log_outputs.each do |expected_log_output|
    #     expect(Rails.logger).to receive(:error).with(include(expected_log_output))
    #   end
    #   expect {
    #     res = service.ingest_publications(test_publications)
    #     expect(res[:admin_set_title]).to eq('Open_Access_Articles_and_Book_Chapters')
    #     expect(res[:depositor]).to eq('admin')
    #     expect(res[:failed].count).to eq(1)
    #     expect(res[:failed].first[:publication]).to eq(failing_publication)
    #     expect(res[:failed].first[:error]).to eq([StandardError.to_s, test_err_msg])
    #     expect(res[:ingested]).to match_array(ingested_publications)
    #     expect(res[:time]).to be_a(Time)
    #   }.to change { Article.count }.by(ingested_publications.size)
    end
  end
end
