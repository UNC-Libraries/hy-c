# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::DimensionsIngestService do
  let(:config) {
    {
      'admin_set' => 'Open_Access_Articles_and_Book_Chapters',
      'depositor_onyen' => 'admin',
      'download_delay' => 0,
      'wiley_tdm_api_token' => 'test-token'
    }
  }
  let(:dimensions_ingest_test_fixture) do
    File.read(File.join(Rails.root, '/spec/fixtures/files/dimensions_ingest_test_fixture.json'))
  end
  let(:admin) { FactoryBot.create(:admin, uid: 'admin') }
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
  let(:test_publications) { JSON.parse(dimensions_ingest_test_fixture)['publications'] }

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

    context 'when admin set is not found' do
      it 'raises an ActiveRecord::RecordNotFound error' do
        allow(AdminSet).to receive(:where).and_return([])
        allow(User).to receive(:find_by).and_return(admin)
        expect { described_class.new(config) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when user is not found' do
      it 'raises an ActiveRecord::RecordNotFound error' do
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
        processed_publication = nil
        expect {
          processed_publication = service.process_publication(publication)
        }.to change { FileSet.count }.by(1)
          .and change { Article.count }.by(1)
        expect(processed_publication.file_sets).to be_instance_of(Array)
        fs = processed_publication.file_sets.first
        expect(fs).to be_instance_of(FileSet)
        expect(fs.depositor).to eq(admin.uid)
        expect(fs.visibility).to eq(processed_publication.visibility)
        expect(fs.parent).to eq(processed_publication)
      end

      it 'deletes the PDF file after processing' do
        publication = test_publications.first
        fixed_time = Time.now
        formatted_time = fixed_time.strftime('%Y%m%d%H%M%S%L')
        test_file_path = "#{ENV['TEMP_STORAGE']}/downloaded_pdf_#{formatted_time}.pdf"

        # Mock the time to control file naming
        allow(Time).to receive(:now).and_return(fixed_time)

        allow(File).to receive(:open).and_call_original
        allow(File).to receive(:delete).and_call_original
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:join).and_call_original

        expect {
          service.process_publication(publication)
        }.to change { Article.count }.by(1)

        expect(File).to have_received(:join).with(ENV['TEMP_STORAGE'], "downloaded_pdf_#{formatted_time}.pdf")
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
      expected_failing_publication = test_publications.first
      test_err_msg = 'Test error'
      expected_log_outputs = [
        "Error ingesting publication '#{expected_failing_publication['title']}' with Dimensions ID: #{expected_failing_publication['id']}",
        [StandardError.to_s, test_err_msg].join($RS)
      ]
      ingested_publications = test_publications[1..-1].map do |pub|
        pub.merge('pdf_attached' => true)
      end

      # Stub the process_publication method to raise an error for the first publication only
      allow(service).to receive(:process_publication).and_call_original
      allow(service).to receive(:process_publication).with(expected_failing_publication).and_raise(StandardError, test_err_msg)

      expect(Rails.logger).to receive(:error).with(expected_log_outputs[0])
      expect(Rails.logger).to receive(:error).with(include(expected_log_outputs[1]))

      expect {
        @res = service.ingest_publications(test_publications)
      }.to change { Article.count }.by(ingested_publications.size)

      actual_failed_publication = @res[:failed].first
      actual_failed_publication_error = @res[:failed].first['error']
      # Removing error from the failed publication for comparison
      actual_failed_publication.delete('error')
      expect(actual_failed_publication).to eq(expected_failing_publication)
      expect(actual_failed_publication_error).to eq([StandardError.to_s, test_err_msg])

      expect(@res[:admin_set_title]).to eq('Open_Access_Articles_and_Book_Chapters')
      expect(@res[:depositor]).to eq('admin')
      expect(@res[:failed].count).to eq(1)

      # Removing article_id from the ingested publications for comparison
      @res[:ingested].each_with_index do |ingested_pub, index|
        ingested_pub.delete('article_id')
      end

      expect(@res[:ingested]).to match_array(ingested_publications)
      expect(@res[:time]).to be_a(Time)
    end
  end

  describe '#extract_pdf' do
    it 'extracts the PDF from the publication' do
      publication = test_publications.last
      pdf_path = service.extract_pdf(publication)
      expect(File.exist?(pdf_path)).to be true
      expect(publication['pdf_attached']).to be true
    end

    it 'returns nil if the publication does not have a linkout url' do
      publication = test_publications.first
      publication['linkout'] = nil  # Ensure linkout URL is missing
      expect(Rails.logger).to receive(:warn).with('Failed to retrieve PDF. Publication does not have a linkout URL.')
      expect(service.extract_pdf(publication)).to be nil
      expect(publication['pdf_attached']).to be false
    end

    it 'returns nil if the publication linkout url is not a PDF and logs an error' do
      publication = test_publications.first
      publication['linkout'] = 'https://test-url.com/'
      stub_request(:head, 'https://test-url.com/')
        .to_return(status: 200, headers: { 'Content-Type' => 'application/text' })
      expect(Rails.logger).to receive(:error).with("Failed to retrieve PDF from URL 'https://test-url.com/'. Incorrect content type: 'application/text'")
      expect(service.extract_pdf(publication)).to be nil
      expect(publication['pdf_attached']).to be false
    end

    it 'returns nil if the PDF download fails and logs an error' do
      publication = test_publications.first
      publication['linkout'] = 'https://test-url.com/'
      stub_request(:get, 'https://test-url.com/')
        .to_return(body: '', status: 500)
      expect(Rails.logger).to receive(:error).with("Failed to retrieve PDF from URL 'https://test-url.com/'. Failed to download PDF: HTTP status '500'")
      expect(service.extract_pdf(publication)).to be nil
      expect(publication['pdf_attached']).to be false
    end

    it 'logs a warning and proceeds with GET if HEAD request fails' do
      publication = test_publications.first
      publication['linkout'] = 'https://test-url.com/'
      stub_request(:head, 'https://test-url.com/')
        .to_return(status: 500)
      expect(Rails.logger).to receive(:warn).with('Received a non-200 response code (500) when making a HEAD request to the PDF URL: https://test-url.com/')
      pdf_path = service.extract_pdf(publication)
      expect(publication['pdf_attached']).to be true
      expect(File.exist?(pdf_path)).to be true
    end

    it 'does not send HEAD requests when attempting to retrieve a PDF from any API' do
      publication = test_publications.first
      publication['linkout'] = 'https://api.test-url.com/'
      stub_request(:get, 'https://api.test-url.com/')
        .to_return(body: pdf_content, status: 200, headers: { 'Content-Type' => 'application/pdf' })
      expect(Rails.logger).to receive(:info).with("Skipping content type check for API URL: #{publication['linkout']}")
      service.extract_pdf(publication)
    end

    context 'when the publication linkout url is a Wiley Online Library URL' do
      let (:test_doi) { '10.1002/cne.24143' }
      let (:encoded_doi) { URI.encode_www_form_component(test_doi) }
      let (:wiley_test_publication) do
        publication = test_publications.first
        publication['linkout'] = "https://onlinelibrary.wiley.com/doi/pdfdirect/#{test_doi}"
        publication['doi'] = test_doi
        publication
      end

      before do
        allow(service).to receive(:download_pdf).and_call_original
        stub_request(:head, "https://api.wiley.com/onlinelibrary/tdm/v1/articles/#{encoded_doi}")
        .to_return(status: 200, headers: { 'Content-Type' => 'application/pdf' })
      end

      it 'attempts to download a PDF using their API' do
        stub_request(:get, "https://api.wiley.com/onlinelibrary/tdm/v1/articles/#{encoded_doi}")
        .to_return(body: pdf_content, status: 200, headers: { 'Content-Type' => 'application/pdf' })
        pdf_path = service.extract_pdf(wiley_test_publication)
        expect(service).to have_received(:download_pdf).with(
          "https://api.wiley.com/onlinelibrary/tdm/v1/articles/#{encoded_doi}",
          wiley_test_publication,
          'Wiley-TDM-Client-Token' => config['wiley_tdm_api_token']
        )
      end

      it 'raises a unique error if the Wiley API returns a non 200 status code with rate limit message in the body after a retry' do
        rate_limit_error = '"{""fault"":{""faultstring"":""Rate limit quota violation. Quota limit  exceeded. Identifier : 3c6dd2e9-faf5-4017-9039-b09388fc5a08"",""detail"":{""errorcode"":""policies.ratelimit.QuotaViolation""}}}"'
        stub_request(:get, "https://api.wiley.com/onlinelibrary/tdm/v1/articles/#{encoded_doi}")
        .to_return(body: rate_limit_error, status: 403, headers: { 'Content-Type' => 'application/pdf' })
        expect(Rails.logger).to receive(:warn).with('Wiley-TDM API rate limit exceeded. Retrying request in 0 seconds.')
        expect(Rails.logger).to receive(:error).with("Failed to retrieve PDF from URL 'https://api.wiley.com/onlinelibrary/tdm/v1/articles/#{encoded_doi}'. Failed to download PDF: HTTP status '403' (Exceeded Wiley-TDM API rate limit)")
        service.extract_pdf(wiley_test_publication)
      end
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
      publication = test_publications.find { |pub| pub['title'] == 'Patient Perspectives on Performance of a Smartphone App for Atrial FibrillationSelf-Management' }
      # Explicitly defined creator size in case a bug interferes with creation of the expected author metadata
      expected_creator_size = 6
      expected_author_metadata = publication['authors'].map do |author|
        {
          'name' => "#{[author['last_name'], author['first_name']].compact.join(', ')}",
          'other_affiliation' => author['affiliations'][0]['raw_affiliation'],
          'orcid' => author['orcid']
        }
      end
      article = service.article_with_metadata(publication)
      expect(article).to be_instance_of(Article)
      expect(article.persisted?).to be true
      expect(article.valid?).to be true
      expect(article.title).to eq(['Patient Perspectives on Performance of a Smartphone App for Atrial FibrillationSelf-Management'])
      expect(article.creators.size).to eq(expected_creator_size)
      all_creators_names = article.creators.map { |creator| creator.attributes['name'] }
      expected_author_metadata.each_with_index do |expected_author, index|
        author = article.creators.find { |creator| creator.attributes['name'][0] == expected_author['name'] }
        expect(author).to be_present
        expect(author[:name]).to eq([expected_author['name']])
        expect(author[:other_affiliation]).to eq([expected_author['other_affiliation']])
        expect(author[:orcid]).to eq(["https://orcid.org/#{expected_author['orcid'][0]}"])
      end
      expect(article.keyword).to eq(publication['concepts'])
      expect(article.abstract).to eq([publication['abstract']])
      expect(article.depositor).to eq(admin.uid)
      expect(article.date_issued).to eq('2022-10-01')
      expect(article.dcmi_type).to match_array(['http://purl.org/dc/dcmitype/Text'])
      expect(article.funder).to match_array(['National Institute of Allergy and Infectious Diseases'])
      expect(article.identifier).to match_array(['DOI: https://dx.doi.org/10.2147/ppa.s366963', 'Dimensions ID: pub.1151967112', 'PMCID: PMC9587729', 'PMID: 36281351'])
      expect(article.issn).to match_array(['1177-889X'])
      expect(article.journal_issue).to eq('10')
      expect(article.journal_title).to eq('Patient preference and adherence')
      expect(article.journal_volume).to eq('16')
      expect(article.publisher).to match_array(['Taylor & Francis'])
      expect(article.resource_type).to match_array(['Article'])
      expect(article.rights_statement).to eq('http://rightsstatements.org/vocab/InC/1.0/')
      expect(article.rights_statement_label).to eq('In Copyright')
      expect(article.visibility).to eq('restricted')
    end

    it 'creates an article with a default abstract and empty keywords if they are missing' do
      publication = test_publications.find { |pub| pub['title'] == 'Patient Perspectives on Performance of a Smartphone App for Atrial FibrillationSelf-Management' }
      publication['abstract'] = nil
      publication['concepts'] = nil
      article = service.article_with_metadata(publication)
      expect(article.abstract).to eq(['N/A'])
      expect(article.keyword).to eq([])
    end
  end
end
