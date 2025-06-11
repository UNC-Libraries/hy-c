# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::PubmedIngest::PubmedIngestService do
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
      expect(service).to be_a(Tasks::PubmedIngest::PubmedIngestService)
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
      expect(logger_spy).to receive(:error).with(/Error processing record/).twice
      expect(logger_spy).to receive(:error).with(/Backtrace/).twice
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

      # Grab the first successfully ingested article and validate metadata
      ingested_article = @res[:successfully_ingested][0]['article']
      # Sanity check and validate article title was set correctly
      expect(ingested_article).not_to be_nil
      # Identifier field assertions
      expect(ingested_article.identifier).to include(
                        'PMID: 31721082',
                        'PMCID: PMC8012007',
                        'DOI: https://dx.doi.org/10.1007/s13365-019-00806-2'
                      )
      expect(ingested_article.issn).to include('1538-2443')
      # Basic attribute assertions
      expect(ingested_article.admin_set).to eq(admin_set)
      expect(ingested_article.depositor).to eq(admin.uid)
      expect(ingested_article.resource_type).to eq(['Article'])
      expect(ingested_article.title).to eq(['The Veterans Aging Cohort Study Index is not associated with HIV-associated neurocognitive disorders in Uganda.'])
      expect(ingested_article.abstract.first).to include(
        'In this first study of the VACS Index in sub-Saharan Africa, ' \
        'we found no association between VACS Index score and HAND.'
      )
      expect(ingested_article.date_issued).to eq('2019-11-14')
      # No explicit publisher in the XML, so expect it to be empty
      expect(ingested_article.publisher).to be_empty
      expect(ingested_article.keyword).to eq(['HIV-associated neurocognitive disorder', 'Global health', 'HIV', 'Veterans aging cohort study index', 'Uganda'])
      expect(ingested_article.funder).to eq(['NINDS NIH HHS', 'NIMH NIH HHS', 'National Institute of Allergy and Infectious Diseases', 'NIAID NIH HHS'])
      # Validate creator size, verify fields are present
      expect(ingested_article.creators.length).to eq(12)
      ingested_article.creators.each_with_index do |creator, i|
        expect(creator).to be_a(Person)
        expect(creator['name']).to be_present
        expect(creator['orcid']).to be_present
        expect(creator['index']).to be_present
      end
      # Validate specific creator, selected by name
      sample_creator = ingested_article.creators.find { |c| active_relation_to_string(c['name']) == 'Awori, Violet' }
      expect(sample_creator).to be_present
      expect(active_relation_to_string(sample_creator['index'])).to eq('0')
      expect(active_relation_to_string(sample_creator['orcid'])).to eq('https://orcid.org/0000-0001-0000-0027')
      expect(active_relation_to_string(sample_creator['other_affiliation'])).to include('Aga Khan University Hospital, Nairobi, Kenya.')
      # Retrieve another sample creator with non-UNC and UNC affiliations
      sample_creator_multi_affil = ingested_article.creators.find { |c| active_relation_to_string(c['name']) == 'Kisakye, Alice' }
      expect(sample_creator_multi_affil).to be_present
      expect(active_relation_to_string(sample_creator_multi_affil['other_affiliation'])).to eq('Department of Orthopaedics, University of North Carolina-Chapel Hill, Chapel Hill, North Carolina.')
      # Journal and page assertions
      expect(ingested_article.journal_title).to eq('Journal of neurovirology')
      expect(ingested_article.journal_volume).to eq('26')
      expect(ingested_article.journal_issue).to eq('2')
      expect(ingested_article.page_start).to eq('252')
      expect(ingested_article.page_end).to eq('256')
      # Rights and type assertions
      expect(ingested_article.rights_statement).to eq('http://rightsstatements.org/vocab/InC/1.0/')
      expect(ingested_article.rights_statement_label).to eq('In Copyright')
      expect(ingested_article.dcmi_type).to include('http://purl.org/dc/dcmitype/Text')
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
      expect(logger_spy).to receive(:error).with(/Error processing record/).twice
      expect(logger_spy).to receive(:error).with(/Backtrace/).twice
      # Expect the article count to change by 2
      expect {
        @res = service.ingest_publications
      }.to change { Article.count }.by(2)
      debug_out_path = Rails.root.join('tmp', 'pubmed_ingest_debug_output.json')
      File.open(debug_out_path, 'w') { |f| f.write(JSON.pretty_generate(@res)) }
      success_pmcids = @res[:successfully_ingested].map { |row| row['pmcid'] }
      failed_pmcids = @res[:failed].map { |row| row['pmcid'] }

      # Expect the PMIDs from the success sample to be in "successfully_ingested" and the failing sample to be in "failed"
      expect(success_pmcids).to match_array(sample['success'].map { |a| a.xpath('.//article-id[@pub-id-type="pmcid"]').text })
      expect(failed_pmcids).to match_array(failing_sample_pmcids)
      # Expect the newly ingested array size to be 2 and the failed array size to be 2
      expect(@res[:successfully_ingested].length).to eq(2)
      expect(@res[:failed].length).to eq(2)


      # Grab the first successfully ingested article and validate metadata
      ingested_article = @res[:successfully_ingested][0]['article']
      # Sanity check and validate article title was set correctly
      expect(ingested_article).not_to be_nil
      # Identifier field assertions
      expect(ingested_article.identifier).to include(
                        'PMID: 37160645',
                        'PMCID: PMC10169148',
                        'DOI: https://dx.doi.org/10.1007/s10488-023-01270-1'
                      )
      expect(ingested_article.issn).to include('1573-3289')
      # Basic attribute assertions
      expect(ingested_article.admin_set).to eq(admin_set)
      expect(ingested_article.depositor).to eq(admin.uid)
      expect(ingested_article.resource_type).to eq(['Article'])
      expect(ingested_article.title).to eq(['Comparing Medicaid Expenditures for Standard and Enhanced Therapeutic Foster Care'])
      # Abstract assertions
      expect(ingested_article.abstract.first).to include(
        'The purpose of this study was to compare Medicaid expenditures associated with TFC ' \
        'with Medicaid expenditures associated with an enhanced higher-rate service called ' \
        'Intensive Alternative Family Treatment (IAFT).'
      )
      expect(ingested_article.date_issued).to eq('2023-05-09')
      expect(ingested_article.publisher).to include('Test Publisher')
      expect(ingested_article.keyword).to eq(['ontology', 'midwifery care', 'Adolescent', 'Cost analysis', 'phenotype', 'sociodemographic', 'Medicaid', 'pregnancy loss', 'semantics', 'Mental health services', 'miscarriage', 'Hispanic/Latinas', 'integration', 'acculturation', 'intimate partner violence'])
      expect(ingested_article.funder).to eq(['National Human Genome Research Institute', 'Office of Science', 'Center of Excellence in Genomic Science', 'BBSRC Growing Health', 'National Institutes of Health', 'Office of the Director', 'NIH National Human Genome Research Institute Phenomics First Resource', 'Open Targets', 'EMBL-EBI', 'GSK', 'EMBL-EBI Core Funds', 'Dicty database and Stock Center', 'Celgene', 'Takeda', 'Gene Ontology Consortium', 'Biogen', 'Office of Basic Energy Sciences', 'NICHD', 'Wellcome Trust Sanger Institute', 'Alliance of Genome Resources', 'NIH', 'US Department of Energy', 'Wellcome Grant', 'Sanofi', 'Delivering Sustainable Wheat'])
      # Validate creator size, verify fields are present
      expect(ingested_article.creators.length).to eq(4)
      ingested_article.creators.each_with_index do |creator, i|
        expect(creator).to be_a(Person)
        expect(creator['name']).to be_present
        expect(creator['orcid']).to be_present
        expect(creator['index']).to be_present
      end
      # Validate specific creator, selected by name
      sample_creator = ingested_article.creators.find { |c| active_relation_to_string(c['name']) == 'Lanier, Paul' }
      expect(sample_creator).to be_present
      expect(active_relation_to_string(sample_creator['index'])).to eq('1')
      expect(active_relation_to_string(sample_creator['orcid'])).to eq('http://orcid.org/0000-0003-4360-3269')
      expect(active_relation_to_string(sample_creator['other_affiliation'])).to include('School of Social Work, UNC Chapel Hill')
      # Retrieve another sample creator with non-UNC and UNC affiliations
      sample_creator_multi_affil = ingested_article.creators.find { |c| active_relation_to_string(c['name']) == 'Doe, John' }
      expect(sample_creator_multi_affil).to be_present
      expect(active_relation_to_string(sample_creator_multi_affil['other_affiliation'])).to eq('School of Social Work, UNC Chapel Hill')
      # Journal and page assertions
      expect(ingested_article.journal_title).to eq('Administration and Policy in Mental Health')
      expect(ingested_article.journal_volume).to eq('12')
      expect(ingested_article.journal_issue).to eq('435313')
      expect(ingested_article.page_start).to eq('1')
      expect(ingested_article.page_end).to eq('10')
      # Rights and type assertions
      expect(ingested_article.rights_statement).to eq('http://rightsstatements.org/vocab/InC/1.0/')
      expect(ingested_article.rights_statement_label).to eq('In Copyright')
      expect(ingested_article.dcmi_type).to include('http://purl.org/dc/dcmitype/Text')
      # Retrieve two more samples to validate fallback logic
      ingested_article = @res[:successfully_ingested][1]['article']
      # Validate specific creators for fallback logic
      fallback_logic_sample = [
        ingested_article.creators.find { |c| active_relation_to_string(c['name']) == 'Carrillo-Kappus, Kristen' },
        ingested_article.creators.find { |c| active_relation_to_string(c['name']) == 'Bello, Susan M' }
      ]
      expect(fallback_logic_sample[0]['other_affiliation']).to include(
        "Women's Health Center, Isabella Citizens for Health, Inc, Mt. Pleasant, Michigan; and the Department" \
        ' of Obstetrics and Gynecology, University of North Carolina at Chapel Hill, Chapel Hill, and the Department' \
        ' of Biostatistics and Bioinformatics and the Department of Obstetrics and Gynecology, Duke University Medical Center, Durham, North Carolina.'
      )
      expect(fallback_logic_sample[1]['other_affiliation']).to include('The Jackson Laboratory')
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

  def active_relation_to_string(active_relation)
    active_relation.to_a.map(&:to_s).join('; ')
  end
end
