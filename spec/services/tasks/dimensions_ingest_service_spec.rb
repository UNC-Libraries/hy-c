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
    context 'when admin set and depositor are found' do
      it 'successfully initializes the service' do
        expect { described_class.new(config) }.not_to raise_error
      end
    end

    context 'when admin set or user is not found' do
      it 'raises an error' do
        allow(AdminSet).to receive(:where).and_return([])
        allow(User).to receive(:find_by).and_return(admin)
        expect { described_class.new(config) }.to raise_error(ActiveRecord::RecordNotFound)
        allow(AdminSet).to receive(:where).and_return([admin_set])
        allow(User).to receive(:find_by).and_return(nil)
        expect { described_class.new(config) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe '#process_publication' do
    context 'when the publication has a PDF' do
      it 'creates article, handles workflows, and attaches PDF' do
        publication = test_publications.first
        expect(service).to receive(:create_sipity_workflow)
        expect {
          processed_publication = service.process_publication(publication)
          expect(processed_publication.file_sets).to be_instance_of(Array)
          fs = processed_publication.file_sets.first
          expect(fs).to be_instance_of(FileSet)
          expect(fs.depositor).to eq(admin.uid)
          expect(fs.visibility).to eq(processed_publication.visibility)
          expect(fs.parent).to eq(processed_publication)
        }.to change { FileSet.count }.by(1)
        .and change { Article.count }.by(1)
      end

      it 'deletes the PDF file after processing' do
        publication = test_publications.first
        fixed_time = Time.now.to_i
        test_file_path = "#{ENV['TEMP_STORAGE']}/downloaded_pdf_#{fixed_time}.pdf"

        # Mock the time to control file naming
        allow(Time).to receive(:now).and_return(Time.at(fixed_time))

        allow(File).to receive(:open).and_call_original
        allow(File).to receive(:delete).and_call_original
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:join).and_call_original

        expect {
          service.process_publication(publication)
        }.to change { Article.count }.by(1)

        expect(File).to have_received(:join).with(ENV['TEMP_STORAGE'], "downloaded_pdf_#{fixed_time}.pdf")
        expect(File).to have_received(:open).with(test_file_path).at_least(:once)
        expect(File).to have_received(:delete).with(test_file_path)
        expect(File.exist?(test_file_path)).to be false
      end
    end
    context 'when the publication does not have a PDF' do
      it 'creates article and handles workflows' do
        publication = test_publications.first
        publication['linkout'] = nil
        expect(service).to receive(:create_sipity_workflow)
        expect {
          processed_publication = service.process_publication(publication)
          expect(processed_publication.file_sets).to be_empty
        }.to change { Article.count }.by(1)
        .and change { FileSet.count }.by(0)
      end
    end
  end

  describe '#ingest_publications' do
    it 'processes each publication and handles failures' do
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

    it 'returns nil if the publication linkout url is not a PDF and logs an error' do
      publication = test_publications.first
      publication['linkout'] = 'https://test-url.com/'
      stub_request(:head, 'https://test-url.com/')
      .to_return(status: 200, headers: { 'Content-Type' => 'application/text' })
      expect(Rails.logger).to receive(:error).with("Failed to retrieve PDF from URL 'https://test-url.com/'. Incorrect content type: 'application/text'")
      expect(service.extract_pdf(publication)).to be nil
    end

    it 'returns nil if the PDF download fails and logs an error' do
      publication = test_publications.first
      publication['linkout'] = 'https://test-url.com/'
      stub_request(:get, 'https://test-url.com/')
      .to_return(body: '', status: 500)
      expect(Rails.logger).to receive(:error).with("Failed to retrieve PDF from URL 'https://test-url.com/'. Failed to download PDF: HTTP status '500'")
      expect(service.extract_pdf(publication)).to be nil
    end
  end

  describe '#article_with_metadata' do
    it 'can create a valid article' do
      publication = test_publications.first
      expect do
        service.article_with_metadata(publication)
      end.to change { Article.count }.by(1)
    end

    it 'creates an article with metadata' do
      publication = test_publications.first
      article = service.article_with_metadata(publication)
      expect(article).to be_instance_of(Article)
      expect(article.persisted?).to be true
      expect(article.valid?).to be true
      expect(article.title).to eq(['Polypharmacy in US Medicare beneficiaries with antineutrophil cytoplasmic antibody vasculitis'])
      first_creator = article.creators.find { |creator| creator[:index] == ['1'] }
      expect(first_creator.attributes['name']).to match_array(['Carolyn T Thorpe'])
      expect(first_creator.attributes['other_affiliation']).to match_array(['Veterans Affairs Pittsburgh Healthcare System, PA.'])
      expect(first_creator.attributes['orcid']).to match_array(['https://orcid.org/0000-0002-7662-7497'])
      expect(article.abstract).to include(/Treatment requirements of antineutrophil cytoplasmic autoantibody vasculitis/)
      expect(article.date_issued).to eq('2023-07-01')
      expect(article.dcmi_type).to match_array(['http://purl.org/dc/dcmitype/Text'])
      expect(article.funder).to match_array(['acronym: NIAID||city_name: Bethesda||country_code: US||country_name: United States||id: grid.419681.3||latitude: 39.066647||linkout: ["https://www.niaid.nih.gov"]||longitude: -77.11183||name: National Institute of Allergy and Infectious Diseases||state_name: Maryland||types: ["Government"]'])
      expect(article.identifier).to match_array(['DOI: https://dx.doi.org/10.18553/jmcp.2023.29.7.770', 'Dimensions ID: pub.1160372243', 'PMCID: PMC10387912', 'PMID: 37404075'])
      expect(article.issn).to match_array(['2376-0540', '2376-1032'])
      expect(article.journal_issue).to eq('7')
      expect(article.journal_title).to eq('Journal of Managed Care & Specialty Pharmacy')
      expect(article.journal_volume).to eq('29')
      expect(article.publisher).to match_array(['Academy of Managed Care Pharmacy'])
      expect(article.resource_type).to match_array(['Article'])
      expect(article.rights_statement).to eq('http://rightsstatements.org/vocab/InC/1.0/')
      expect(article.rights_statement_label).to eq('In Copyright')
      expect(article.visibility).to eq('restricted')
    end
  end

end
