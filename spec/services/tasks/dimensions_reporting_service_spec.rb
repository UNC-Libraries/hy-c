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

  describe '#initialize' do
      it 'successfully initializes the service' do
        expect { described_class.new([]) }.not_to raise_error
      end
    end

#   describe '#ingest_publications' do
#     it 'processes each publication and handles failures' do
#       failing_publication = test_publications.first
#       test_err_msg = 'Test error'
#       expected_log_outputs = [
#         "Error ingesting publication '#{failing_publication['title']}'",
#         [StandardError.to_s, test_err_msg].join($RS)
#       ]
#       ingested_publications = test_publications[1..-1]

#       # Stub the process_publication method to raise an error for the first publication only
#       allow(service).to receive(:process_publication).and_call_original
#       allow(service).to receive(:process_publication).with(failing_publication).and_raise(StandardError, test_err_msg)

#       expect(Rails.logger).to receive(:error).with(expected_log_outputs[0])
#       expect(Rails.logger).to receive(:error).with(include(expected_log_outputs[1]))
#       expect {
#         res = service.ingest_publications(test_publications)
#         expect(res[:admin_set_title]).to eq('Open_Access_Articles_and_Book_Chapters')
#         expect(res[:depositor]).to eq('admin')
#         expect(res[:failed].count).to eq(1)
#         expect(res[:failed].first[:publication]).to eq(failing_publication)
#         expect(res[:failed].first[:error]).to eq([StandardError.to_s, test_err_msg])
#         expect(res[:ingested]).to match_array(ingested_publications)
#         expect(res[:time]).to be_a(Time)
#       }.to change { Article.count }.by(ingested_publications.size)
#     end
#   end
end
