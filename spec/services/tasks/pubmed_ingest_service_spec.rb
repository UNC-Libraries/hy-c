# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::PubmedIngestService do
  let(:admin_set) do
    FactoryBot.create(:admin_set, title: ['Open_Access_Articles_and_Book_Chapters'])
  end
  let(:admin) { FactoryBot.create(:admin, uid: 'admin') }
  let(:config) do
    {
      'admin_set_title' => admin_set.title.first,
      'depositor_onyen' => admin.uid,
      'attachment_results' => {skipped: []}
    }
  end
  let(:service) { described_class.new(config) }
  let(:pdf_content) { File.binread(File.join(Rails.root, '/spec/fixtures/files/sample_pdf.pdf')) }
  let(:visibility) { Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE }
  let(:permission_template) do
    FactoryBot.create(:permission_template, source_id: admin_set.id)
  end
  let(:workflow) do
    FactoryBot.create(:workflow, permission_template_id: permission_template.id, active: true)
  end
  let(:workflow_state) do
    FactoryBot.create(:workflow_state, workflow_id: workflow.id, name: 'deposited')
  end
  let(:work) do
    FactoryBot.create(:article, title: ['Sample Work Title'], admin_set_id: admin_set.id)
  end

  before do
    admin_set
    permission_template
    workflow
    workflow_state
    allow(AdminSet).to receive(:where).with(title: 'Open_Access_Articles_and_Book_Chapters').and_return([admin_set])
    # stub virus checking
    allow(Hyrax::VirusCheckerService).to receive(:file_has_virus?) { false }
    # stub longleaf job
    allow(RegisterToLongleafJob).to receive(:perform_later).and_return(nil)
    # stub FITS characterization
    allow(CharacterizeJob).to receive(:perform_later)
  end

  describe '#attach_pubmed_file' do
    let(:file_path) { Rails.root.join('spec', 'fixtures', 'files', 'sample_pdf.pdf') }
    let(:depositor) { FactoryBot.create(:user, uid: 'depositor') }

    it 'attaches a PDF to the work' do
      work_hash = {
        work_id: work.id,
        work_type: 'Article',
        title: 'Sample Work Title',
        admin_set_id: admin_set.id,
        admin_set_name: ['Open_Access_Articles_and_Book_Chapters']
      }
      result = nil
      expect {
        result = service.attach_pubmed_file(work_hash, file_path, depositor.uid, visibility)
      }.to change { FileSet.count }.by(1)
      expect(result).to be_instance_of(FileSet)
      expect(result.depositor).to eq(depositor.uid)
      expect(result.visibility).to eq(visibility)
    end
  end

  describe '#batch_retrieve_metadata' do
    let(:mock_attachment_results) do
      json = JSON.parse(File.read(Rails.root.join('spec', 'fixtures', 'files', 'pubmed_ingest_test_fixture_2.json')))
      base_pmid = 100000
      base_pmcid = 200000
      # Add 800 rows to the skipped array
      800.times do |i|
        index_str = format('%03d', i + 1)
        if i.even?
          # pmid-only row
          json["skipped"] << {
            "file_name" => "test_file_#{index_str}.pdf",
            "cdr_url" => "https://cdr.lib.unc.edu/concern/articles/#{index_str}",
            "pmid" => (base_pmid + i).to_s,
            "doi" => "doi-#{index_str}",
            "pdf_attached" => "Skipped: No CDR URL"
          }
        else
          # pmcid-only row
          json["skipped"] << {
            "file_name" => "test_file_#{index_str}.pdf",
            "cdr_url" => "https://cdr.lib.unc.edu/concern/articles/#{index_str}",
           "pmcid" => "PMC#{base_pmcid + i}",
            "doi" => "doi-#{index_str}",
            "pdf_attached" => "Skipped: No CDR URL"
          }
        end
      end
    end
    let(:config) do
      {
        'admin_set_title' => admin_set.title.first,
        'depositor_onyen' => 'test_depositor',
        'attachment_results' => mock_attachment_results
      }
    end
    let(:pubmed_ingest_service) { described_class.new(config) }

    it 'retrieves metadata for pmid and pmcid' do
      # Mock the HTTP response for the PubMed API
      stub_request(:get, /eutils.ncbi.nlm.nih.gov/).to_return(status: 200, body: '<PubmedArticle><PubmedData></PubmedData></PubmedArticle>')

      # Call the method
      result = pubmed_ingest_service.batch_retrieve_metadata

      # Check that the metadata was retrieved correctly
      expect(result).not_to be_empty
      expect(result.size).to eq(800)
      expect(result.first).to be_a(Nokogiri::XML::Element)
    end
    end
  end