# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::PubmedIngest::Backlog::PubmedIngestService do
  let(:logger_spy) { double('Logger').as_null_object }
  let(:admin_set) do
    FactoryBot.create(:admin_set, title: ['Open_Access_Articles_and_Book_Chapters'])
  end
  let(:admin) { FactoryBot.create(:admin, uid: 'admin') }
  let(:config) do
    {
      'admin_set_title' => admin_set.title.first,
      'depositor_onyen' => admin.uid,
      'attachment_results' => {skipped: []},
      'file_retrieval_directory' => Rails.root.join('spec/fixtures/files')
    }
  end
  let(:service) { described_class.new(config) }
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

  before do
    allow(Rails).to receive(:logger).and_return(logger_spy)
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
    let(:valid_config) do
      {
        'admin_set_title' => admin_set.title.first,
        'depositor_onyen' => admin.uid,
        'attachment_results' => { skipped: [{ 'pdf_attached' => 'Skipped: No CDR URL' }, { 'pdf_attached' => 'Other Reason' }] },
        'file_retrieval_directory' => Rails.root.join('spec/fixtures/files')
      }
    end
    it 'successfully initializes with a valid config' do
      service = described_class.new(valid_config)
      expect(service).to be_a(Tasks::PubmedIngest::Backlog::PubmedIngestService)
    end

    it 'raises ArgumentError when admin_set_title is missing' do
      config = valid_config.except('admin_set_title')
      expect { described_class.new(config) }.to raise_error(ArgumentError, /Missing required config keys/)
    end

    it 'raises ArgumentError when depositor_onyen is missing' do
      config = valid_config.except('depositor_onyen')
      expect { described_class.new(config) }.to raise_error(ArgumentError, /Missing required config keys/)
    end

    it 'raises ArgumentError when attachment_results is missing' do
      config = valid_config.except('attachment_results')
      expect { described_class.new(config) }.to raise_error(ArgumentError, /Missing required config keys/)
    end

    it 'raises RecordNotFound when an AdminSet cannot be found' do
      allow(AdminSet).to receive(:where).with(title: valid_config['admin_set_title']).and_return([])
      expect { described_class.new(valid_config) }.to raise_error(ActiveRecord::RecordNotFound, /AdminSet not found/)
    end

    it 'raises RecordNotFound when a User object cannot be found' do
      allow(User).to receive(:find_by).with(uid: valid_config['depositor_onyen']).and_return(nil)
      expect { described_class.new(valid_config) }.to raise_error(ActiveRecord::RecordNotFound, /User not found/)
    end
  end

  describe '#ingest_publications' do
    let(:mock_response_bodies) do
      {
        'pubmed' => File.read(Rails.root.join('spec/fixtures/files/pubmed_api_response_multi.xml')),
        'pmc' => File.read(Rails.root.join('spec/fixtures/files/pmc_api_response_multi.xml'))
      }
    end

    let(:pubmed_rows) do
      parsed_response = Nokogiri::XML(mock_response_bodies['pubmed'])
      parsed_response.xpath('//PMID').map do |pmid|
        {
          'file_name' => 'sample_pdf.pdf',
          'pmid' => pmid.text,
          'pdf_attached' => 'Skipped: No CDR URL'
        }
      end
    end

    let(:pmc_rows) do
      parsed_response = Nokogiri::XML(mock_response_bodies['pmc'])
      parsed_response.xpath('//article-id[@pub-id-type="pmcid"]').map do |pmcid|
        {
          'file_name' => 'sample_pdf.pdf',
          'pmcid' => pmcid.text,
          'pdf_attached' => 'Skipped: No CDR URL'
        }
      end
    end

    let(:pubmed_config) do
      {
        'admin_set_title' => admin_set.title.first,
        'depositor_onyen' => admin.uid,
        'attachment_results' => { skipped: pubmed_rows, successfully_attached: [], successfully_ingested: [], failed: [], counts: { successfully_ingested: 0, failed: 0, skipped: pubmed_rows.length } },
        'file_retrieval_directory' => Rails.root.join('spec/fixtures/files')
      }
    end

    let(:pmc_config) do
      {
        'admin_set_title' => admin_set.title.first,
        'depositor_onyen' => admin.uid,
        'attachment_results' => { skipped: pmc_rows, successfully_attached: [], successfully_ingested: [], failed: [], counts: { successfully_ingested: 0, failed: 0, skipped: pmc_rows.length } },
        'file_retrieval_directory' => Rails.root.join('spec/fixtures/files')
      }
    end

    before do
      ['pubmed', 'pmc'].each do |db|
        stub_request(:get, %r{https://eutils\.ncbi\.nlm\.nih\.gov/entrez/eutils/efetch\.fcgi\?db=#{db}.*})
        .to_return(
          status: 200,
          body: mock_response_bodies[db],
          headers: { 'Content-Type' => 'text/xml' }
        )
      end
    end

    it 'runs without crashing and returns results hash' do
      service = described_class.new(pubmed_config)

      # Stub everything to prevent any real work
      allow(service).to receive(:batch_retrieve_metadata).and_return(nil)
      service.instance_variable_set(:@retrieved_metadata, [])

      result = service.ingest_publications

      # Just verify it returns the expected structure
      expect(result).to be_a(Hash)
      expect(result).to have_key(:successfully_ingested)
      expect(result).to have_key(:failed)
      expect(result).to have_key(:skipped)
      expect(result).to have_key(:counts)
    end

    it 'logs and records failure if article creation fails' do
      service = described_class.new(pubmed_config)
      allow(service).to receive(:batch_retrieve_metadata)
      metadata = double(name: 'PubmedArticle')
      service.instance_variable_set(:@retrieved_metadata, [metadata])
      allow(service).to receive(:new_article).and_raise(StandardError, 'boom')

      expect(Rails.logger).to receive(:error).with(/Error processing record/)
      service.ingest_publications

      expect(pubmed_config['attachment_results'][:failed].size).to be >= 1
    end


  end

  describe '#attach_pdf' do
    let(:article) do
      Article.create!(
        title: ['Test Article'],
        depositor: admin.uid,
        admin_set: admin_set,
        visibility: Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
      )
    end
    let(:mock_permissions) do
      [{ access: 'read', type: 'group', name: 'public' },
        { access: 'edit', type: 'group', name: 'admin' }]
    end

    before do
      allow(WorkUtilsHelper).to receive(:get_permissions_attributes).and_return(mock_permissions)
    end

    it 'attaches a PDF to the article and updates permissions' do
      skipped_row = { 'pmid' => '12345678', 'pmcid' => 'PMC12345678', 'file_name' => 'sample_pdf.pdf' }

      expect {
        service.send(:attach_pdf, article, skipped_row)
      }.to change { article.file_sets.count }.by(1)

      file_set = article.file_sets.last
      expect(file_set).to be_present
      expect(file_set.read_groups).to include('public')
      expect(file_set.edit_groups).to include('admin')
    end

    it 'raises an error when the PDF file cannot be attached' do
      skipped_row = { 'pmid' => '99999999', 'pmcid' => 'PMC99999999', 'file_name' => 'non_existent.pdf' }
      expect {
        service.send(:attach_pdf, article, skipped_row)
      }.to raise_error(StandardError, /File not found at path/)
    end
  end

  describe '#record_result' do
    it 'records a successful result with generated CDR URL' do
      attachment_results = { counts: { successfully_ingested: 0 }, successfully_ingested: [] }
      config['attachment_results'] = attachment_results
      service = described_class.new(config)

      allow(WorkUtilsHelper).to receive(:generate_cdr_url_for_work_id)
        .with('123').and_return('http://example.com/123')

      service.record_result(
        category: :successfully_ingested,
        file_name: 'test.pdf',
        message: 'ok',
        ids: { work_id: '123', pmid: '1', pmcid: 'PMC1', doi: '10.x' }
      )

      expect(attachment_results[:successfully_ingested].first['cdr_url'])
        .to eq('http://example.com/123')
    end
  end

  describe '#batch_retrieve_metadata' do
    it 'populates @retrieved_metadata from HTTP XML' do
      xml = <<~XML
        <PubmedArticleSet><PubmedArticle><PMID>123</PMID></PubmedArticle></PubmedArticleSet>
      XML
      stub_request(:get, /efetch/).to_return(status: 200, body: xml)
      service.instance_variable_set(:@new_pubmed_works, [{ 'pmid' => '123', 'file_name' => 'x.pdf' }])
      service.send(:batch_retrieve_metadata)
      expect(service.instance_variable_get(:@retrieved_metadata).first.name).to eq('PubmedArticle')
    end
  end

  describe '#attach_pdf_for_existing_work' do
    let(:work) { FactoryBot.create(:article, depositor: admin.uid, admin_set: admin_set) }

    it 'attaches a PDF to an existing work' do
      allow(AdminSet).to receive(:where).with(id: admin_set.id).and_return([admin_set])
      allow_any_instance_of(Tasks::PubmedIngest::Backlog::PubmedIngestService)
        .to receive(:attach_pdf_to_work)
        .and_return(double(update: true))

      result = service.attach_pdf_for_existing_work(
        { work_type: 'Article', work_id: work.id, admin_set_id: admin_set.id },
        Rails.root.join('spec/fixtures/files/sample_pdf.pdf'),
        admin.uid
      )
      expect(result).to respond_to(:update)
    end

    it 'raises and logs when attachment fails' do
      expect(Rails.logger).to receive(:error).with(/Error finding article/)
      expect {
        service.attach_pdf_for_existing_work(
          { work_type: 'Article', work_id: 'badid', admin_set_id: admin_set.id },
          '/nope.pdf',
          admin.uid
        )
      }.to raise_error(StandardError)
    end
  end




  def active_relation_to_string(active_relation)
    active_relation.to_a.map(&:to_s).join('; ')
  end
end
