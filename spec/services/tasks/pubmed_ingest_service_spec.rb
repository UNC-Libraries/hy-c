# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::PubmedIngestService do
  let(:logger_spy) { double('Logger').as_null_object }
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
        'attachment_results' => { skipped: [{ 'pdf_attached' => 'Skipped: No CDR URL' }, { 'pdf_attached' => 'Other Reason' }] }
      }
    end
    it 'successfully initializes with a valid config' do
      service = described_class.new(valid_config)
      expect(service).to be_a(Tasks::PubmedIngestService)
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

    it 'extracts only new Pubmed works from skipped array' do
      service = described_class.new(valid_config)
      new_pubmed_works = service.instance_variable_get(:@new_pubmed_works)
      expect(new_pubmed_works.size).to eq(1)
      expect(new_pubmed_works.first['pdf_attached']).to eq('Skipped: No CDR URL')
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
          'file_name' => "test_file_#{pmid.text}.pdf",
          'pmid' => pmid.text,
          'pdf_attached' => 'Skipped: No CDR URL'
        }
      end
    end

    let(:pmc_rows) do
      parsed_response = Nokogiri::XML(mock_response_bodies['pmc'])
      parsed_response.xpath('//article-id[@pub-id-type="pmcid"]').map do |pmcid|
        {
          'file_name' => "test_file_#{pmcid.text}.pdf",
          'pmcid' => pmcid.text,
          'pdf_attached' => 'Skipped: No CDR URL'
        }
      end
    end

    let(:pubmed_config) do
      {
        'admin_set_title' => admin_set.title.first,
        'depositor_onyen' => admin.uid,
        'attachment_results' => { skipped: pubmed_rows, successfully_attached: [], successfully_ingested: [], failed: [] }
      }
    end

    let(:pmc_config) do
      {
        'admin_set_title' => admin_set.title.first,
        'depositor_onyen' => admin.uid,
        'attachment_results' => { skipped: pmc_rows, successfully_attached: [], successfully_ingested: [], failed: [] }
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

    it 'processes pubmed articles and handles failures' do
      service = described_class.new(pubmed_config)
      mock_response_body = File.read(Rails.root.join('spec/fixtures/files/pubmed_api_response_multi.xml'))
      parsed_response = Nokogiri::XML(mock_response_body)
      sample = {
        'failing' => parsed_response.xpath('//PubmedArticle')[0..1],
        'success' => parsed_response.xpath('//PubmedArticle')[2..3]
      }
      failing_sample_pmids = sample['failing'].map { |article| article.xpath('MedlineCitation/PMID').text }

      allow(service).to receive(:ingest_publications).and_call_original
      allow(service).to receive(:attach_pdf_to_work).and_wrap_original do |method, *args|
        article, _path, depositor, visibility = args
        new_path = Rails.root.join('spec/fixtures/files/sample_pdf.pdf')

        if article.identifier.any? { |id| failing_sample_pmids.include?(id.gsub(/^PMID:\s*/, '').strip) }
          nil # simulate failure for PMIDs in the failing sample
        else
          method.call(article, new_path, depositor, visibility)
        end
      end
    # Expect errors in logs
      expect(logger_spy).to receive(:error).with(/File attachment error for identifiers:/).twice
    # Expect the article count to change by 2
      expect {
        @res = service.ingest_publications
      }.to change { Article.count }.by(2)
      success_pmids = @res[:successfully_ingested].map { |row| row['pmid'] }
      failed_pmids = @res[:failed].map { |row| row['pmid'] }

    # Expect the PMIDs from the success sample to be in "successfully_ingested" and the failing sample to be in "failed"
      expect(success_pmids).to match_array(sample['success'].map { |a| a.xpath('MedlineCitation/PMID').text })
      expect(failed_pmids).to match_array(failing_sample_pmids)
    # Expect the newly ingested array size to be 2 and the failed array size to be 2
      expect(@res[:successfully_ingested].length).to eq(2)
      expect(@res[:failed].length).to eq(2)

      # Grab the first successfully ingested article and validate metadata. 
      # ingested_article_id = Article.where(title: ['The Veterans Aging Cohort Study Index is not associated with HIV-associated neurocognitive disorders in Uganda.']).first&.id
      # ingested_article = wait_for_attribute(Article, ingested_article_id, :rights_statement)
      # ingested_article.reload
      # WIP: Trying different reference to find the article
      ingested_article = @res[:successfully_ingested][0]['article']
      # Sanity check and validate article title was set correctly
      expect(ingested_article).not_to be_nil
      # Field-level assertions
      expect(ingested_article.abstract.first).to include(
        'In this first study of the VACS Index in sub-Saharan Africa, ' \
        'we found no association between VACS Index score and HAND.'
      ) 
      expect(ingested_article.identifier).to include(
                        'PMID: 31721082',
                        'PMCID: PMC8012007',
                        'DOI: https://dx.doi.org/10.1007/s13365-019-00806-2'
                      )

      # File.open(Rails.root.join('tmp', "1ref_debug_ingested_article_#{ingested_article.id}.json"), 'w') do |file|
      # for attribute in ingested_article.attributes
      #   file.write("#{attribute}: #{ingested_article.attributes[attribute].inspect}\n")
      # end
      # end
      # puts "================================>  Found article: #{ingested_article&.id}, journal_title: #{ingested_article&.journal_title.inspect}"
      expect(ingested_article.journal_title).to eq('Journal of neurovirology')
      expect(ingested_article.journal_volume).to eq('26')
      expect(ingested_article.journal_issue).to eq('2')
      expect(ingested_article.page_start).to eq('252')
      expect(ingested_article.page_end).to eq('256')
      expect(ingested_article.rights_statement).to eq('http://rightsstatements.org/vocab/InC/1.0/')
      expect(ingested_article.rights_statement_label).to eq('In Copyright')
      expect(ingested_article.dcmi_type).to include('http://purl.org/dc/dcmitype/Text')
      # expect(ingested_article.publisher).to eq(['Oxford University Press'])
      # expect(ingested_article.publisher).to eq(['Oxford University Press'])
    end

    it 'processes pmc articles and handles failures' do
      service = described_class.new(pmc_config)
      mock_response_body = File.read(Rails.root.join('spec/fixtures/files/pmc_api_response_multi.xml'))
      parsed_response = Nokogiri::XML(mock_response_body)
      sample = {
        'failing' => parsed_response.xpath('//article')[0..1],
        'success' => parsed_response.xpath('//article')[2..3]
      }
      failing_sample_pmcids = sample['failing'].map { |article| article.xpath('.//article-id[@pub-id-type="pmcid"]').text }
      allow(service).to receive(:ingest_publications).and_call_original
      allow(service).to receive(:attach_pdf_to_work).and_wrap_original do |method, *args|
        article, _path, depositor, visibility = args
        new_path = Rails.root.join('spec/fixtures/files/sample_pdf.pdf')

        if article.identifier.any? { |id| failing_sample_pmcids.include?(id.gsub(/^PMCID:\s*/, '').strip) }
          nil # simulate failure for PMCIDs in the failing sample
        else
          method.call(article, new_path, depositor, visibility)
        end
      end

      # Expect errors in logs
      expect(logger_spy).to receive(:error).with(/File attachment error for identifiers:/).twice
      # Expect the article count to change by 2
      expect {
        @res = service.ingest_publications
      }.to change { Article.count }.by(2)
      success_pmcids = @res[:successfully_ingested].map { |row| row['pmcid'] }
      failed_pmcids = @res[:failed].map { |row| row['pmcid'] }

      # Expect the PMIDs from the success sample to be in "successfully_ingested" and the failing sample to be in "failed"
      expect(success_pmcids).to match_array(sample['success'].map { |a| a.xpath('.//article-id[@pub-id-type="pmcid"]').text })
      expect(failed_pmcids).to match_array(failing_sample_pmcids)
      # Expect the newly ingested array size to be 2 and the failed array size to be 2
      expect(@res[:successfully_ingested].length).to eq(2)
      expect(@res[:failed].length).to eq(2)

      # Grab the first successfully ingested article and validate metadata
      # ingested_article_id = Article.where(title: ['Comparing Medicaid Expenditures for Standard and Enhanced Therapeutic Foster Care']).first&.id
      # ingested_article = wait_for_attribute(Article, ingested_article_id, :rights_statement)
      # ingested_article.reload
      ingested_article = @res[:successfully_ingested][0]['article']
       # Sanity check and validate article title was set correctly
      expect(ingested_article).not_to be_nil
       # Field-level assertions
      expect(ingested_article.abstract.first).to include(
        'The purpose of this study was to compare Medicaid expenditures associated with TFC ' \
        'with Medicaid expenditures associated with an enhanced higher-rate service called ' \
        'Intensive Alternative Family Treatment (IAFT).'
      )
      expect(ingested_article.identifier).to include(
                        'PMID: 37160645',
                        'PMCID: PMC10169148',
                        'DOI: https://dx.doi.org/10.1007/s10488-023-01270-1'
                      )

      puts "[DEBUG] journal_title: #{ingested_article.journal_title.inspect}"
      puts "[DEBUG] journal_volume: #{ingested_article.journal_volume.inspect}"
      puts "[DEBUG] journal_issue: #{ingested_article.journal_issue.inspect}"
      puts "[DEBUG] page_start: #{ingested_article.page_start.inspect}"
      puts "[DEBUG] page_end: #{ingested_article.page_end.inspect}"
      puts "[DEBUG] rights_statement: #{ingested_article.rights_statement.inspect}"
      puts "[DEBUG] rights_statement_label: #{ingested_article.rights_statement_label.inspect}"
      puts "[DEBUG] dcmi_type: #{ingested_article.dcmi_type.inspect}"

      expect(ingested_article.journal_title).to eq('Administration and Policy in Mental Health')
      expect(ingested_article.journal_volume).to eq('12')
      expect(ingested_article.journal_issue).to eq('435313')
      expect(ingested_article.page_start).to eq('1')
      expect(ingested_article.page_end).to eq('10')
      expect(ingested_article.rights_statement).to eq('http://rightsstatements.org/vocab/InC/1.0/')
      expect(ingested_article.rights_statement_label).to eq('In Copyright')
      expect(ingested_article.dcmi_type).to include('http://purl.org/dc/dcmitype/Text')

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
        expect(result).to be_instance_of(FileSet)
        expect(result.depositor).to eq(depositor.uid)
        expect(result.visibility).to eq(visibility)
      }.to change { FileSet.count }.by(1)
    end
  end

  describe '#attach_pdf' do
    let(:depositor) { FactoryBot.create(:user, uid: 'depositor') }
    let(:article) do
      Article.create!(
        title: ['Test Article'],
        depositor: depositor.uid,
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
      metadata = { 'path' => Rails.root.join('spec/fixtures/files/sample_pdf.pdf') }
      skipped_row = { 'pmid' => '12345678', 'pmcid' => 'PMC12345678' }

      expect {
        service.send(:attach_pdf, article, metadata, skipped_row)
      }.to change { article.file_sets.count }.by(1)

      file_set = article.file_sets.last
      expect(file_set).to be_present
      expect(file_set.read_groups).to include('public')
      expect(file_set.edit_groups).to include('admin')
    end

    it 'raises an error when the PDF file cannot be attached' do
      metadata = { 'path' => '/non/existent/path.pdf' }
      skipped_row = { 'pmid' => '99999999', 'pmcid' => 'PMC99999999' }
      expect {
        service.send(:attach_pdf, article, metadata, skipped_row)
      }.to raise_error(StandardError, /File attachment error/)
    end
  end

    def wait_for_attribute(model_class, id, attr_name, timeout: 20, interval: 0.5)
    start_time = Time.now
    loop do
      obj = model_class.find(id)
      obj.reload  
      value = obj.public_send(attr_name)
      return obj if value.present?
      break if Time.now - start_time > timeout
      sleep(interval)
    end
    raise "Timeout: #{attr_name} was not populated within #{timeout} seconds"
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