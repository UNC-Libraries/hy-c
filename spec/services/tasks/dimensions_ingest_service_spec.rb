# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::DimensionsIngestService do
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
  let(:service) { described_class.new(config) }

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
    fixture_publications = JSON.parse(dimensions_ingest_test_fixture)['publications']
    fixture_publications.each do |publication|
      random_number = rand(1..5)
      if random_number == 1
        publication['marked_for_review'] = true
      end
    end
    fixture_publications
  end


  before do
    ActiveFedora::Cleaner.clean!
    admin_set
    permission_template
    workflow
    workflow_state
    # return the FactoryBot admin user when searching for uid: admin from config
    allow(User).to receive(:find_by).with(uid: 'admin').and_return(admin)
    # return the FactoryBot admin_set when searching for admin set from config
    allow(AdminSet).to receive(:where).with(title: 'Open_Access_Articles_and_Book_Chapters').and_return([admin_set])
    stub_request(:head, 'https://test-url.com/')
    .to_return(status: 200, headers: { 'Content-Type' => 'application/pdf' })
    stub_request(:get, 'https://test-url.com/')
    .to_return(body: pdf_content, status: 200, headers: { 'Content-Type' => 'application/pdf' })
  end


  describe '#ingest_publications' do
    # it 'ingests the publications into the database' do
    #   res = service.ingest_publications(test_publications)
    #   puts res
    #   expect { described_class.new.ingest_publications(publications) }
    #     .to change { Publication.count }.by(2)
    # end

    it 'logs an error if a publication fails to ingest but continues with the rest' do
      failing_publication = test_publications.first
      test_err_msg = 'Test Error'
      expected_log_output = "Error ingesting publication '#{failing_publication['title']}': #{test_err_msg}"
      ingested_publications = test_publications[1..-1]

      # Stub the process_publication method to raise an error for the first publication only
      allow(service).to receive(:process_publication).and_call_original
      allow(service).to receive(:process_publication).with(failing_publication).and_raise(StandardError, test_err_msg)

      expect(Rails.logger).to receive(:error).with(expected_log_output)
      expect {
        res = service.ingest_publications(test_publications)
        expect(res[:failed].count).to eq(1)
        expect(res[:failed].first[:publication]).to eq(failing_publication)
        expect(res[:failed].first[:error]).to eq(test_err_msg)
        expect(res[:ingested]).to match_array(ingested_publications)
        expect(res[:time]).to be_a(Time)
      }.to change { Article.count }.by(ingested_publications.size)
    end
  end

  describe '#extract_pdf' do
    it 'extracts the PDF from the publication' do
      publication = test_publications.first
      pdf_path = service.extract_pdf(publication)
      expect(File.exist?(pdf_path)).to be true
    end

    it 'returns nil if the publication does not have a linkout url, or if the publication is nil' do
      publication = test_publications.first
      publication['linkout'] = nil
      expect(Rails.logger).to receive(:error).with('Failed to retrieve PDF. Publication does not have a linkout URL.')
      expect(Rails.logger).to receive(:error).with('Failed to retrieve PDF. Publication is nil.')
      expect(service.extract_pdf(publication)).to be nil
      expect(service.extract_pdf(nil)).to be nil
    end
  end
end
