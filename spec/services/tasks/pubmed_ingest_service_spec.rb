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

  describe '#initialize' do
    it 'successfully initializes with a valid config' do
      pending 'Not implemented yet'
      expect(true).to eq(false)
    end

    it 'raises ArgumentError when admin_set_title is missing' do
      pending 'Not implemented yet'
      expect(true).to eq(false)
    end

    it 'raises ArgumentError when depositor_onyen is missing' do
      pending 'Not implemented yet'
      expect(true).to eq(false)
    end

    it 'raises ArgumentError when attachment_results is missing' do
      pending 'Not implemented yet'
      expect(true).to eq(false)
    end

    it 'raises RecordNotFound when an AdminSet cannot be found' do
      pending 'Not implemented yet'
      expect(true).to eq(false)
    end

    it 'raises RecordNotFound when a User object cannot be found' do
      pending 'Not implemented yet'
      expect(true).to eq(false)
    end

    it 'extracts only new Pubmed works from skipped array' do
      pending 'Not implemented yet'
      expect(true).to eq(false)
    end
  end

  describe '#batch_retrieve_metadata' do
    before do
      stub_request(:get, /eutils.ncbi.nlm.nih.gov/).to_return do |request|
        uri = URI.parse(request.uri)
        params = CGI.parse(uri.query)
        db = params['db'].first
        ids = params['id'].first.split(',')

        xml = build_dynamic_pubmed_xml(ids.count, db)

        {
          status: 200,
          body: xml,
          headers: { 'Content-Type' => 'text/xml' }
        }
      end
    end

    let(:mock_attachment_results) do
      json = JSON.parse(File.read(Rails.root.join('spec', 'fixtures', 'files', 'pubmed_ingest_test_fixture_2.json'))).symbolize_keys
      base_pmid = 100000
      base_pmcid = 200000
      # Add 800 rows to the skipped array
      900.times do |i|
        index_str = format('%03d', i + 1)
        if i.even?
          # pmid-only row
          json[:skipped] << {
            'file_name' => "test_file_#{index_str}.pdf",
            'cdr_url' => "https://cdr.lib.unc.edu/concern/articles/#{index_str}",
            'pmid' => (base_pmid + i).to_s,
            'doi' => "doi-#{index_str}",
            'pdf_attached' => 'Skipped: No CDR URL'
          }
        else
          # pmcid-only row
          json[:skipped] << {
            'file_name' => "test_file_#{index_str}.pdf",
            'cdr_url' => "https://cdr.lib.unc.edu/concern/articles/#{index_str}",
           'pmcid' => "PMC#{base_pmcid + i}",
            'doi' => "doi-#{index_str}",
            'pdf_attached' => 'Skipped: No CDR URL'
          }
        end
      end
      json
    end
    let(:config) do
      {
        'admin_set_title' => admin_set.title.first,
        'depositor_onyen' => admin.uid,
        'attachment_results' => mock_attachment_results
      }
    end
    let(:pubmed_ingest_service) { described_class.new(config) }
    it 'retrieves metadata in batches' do
      result = pubmed_ingest_service.batch_retrieve_metadata
      # Check that the metadata was retrieved correctly
      expect(result).not_to be_empty
      expect(result.size).to eq(900)
      expect(result.first).to be_a(Nokogiri::XML::Element)
    end
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

  def build_dynamic_pubmed_xml(count, db_type)
    Nokogiri::XML::Builder.new do |xml|
      if db_type == 'pubmed'
        xml.PubmedArticleSet {
          count.times do |i|
            xml.PubmedArticle {
              xml.MedlineCitation {
                xml.PMID "100000#{i}"
              }
              xml.Article {
                xml.ArticleTitle "Mocked PubMed Article #{i}"
              }
            }
          end
        }
      else
        xml.ArticleSet {
          count.times do |i|
            xml.article {
              xml.front {
                xml.send('article-meta') {
                  xml.send('pub-id', "200000#{i}", 'pub-id-type' => 'pmcid')
                  xml.title "Mocked PMC Article #{i}"
                }
              }
            }
          end
        }
      end
    end.to_xml
  end
end
