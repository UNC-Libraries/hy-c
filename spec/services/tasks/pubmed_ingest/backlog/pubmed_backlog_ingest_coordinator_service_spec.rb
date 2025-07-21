# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::PubmedIngest::PubmedBacklogIngestCoordinatorService do
  let(:logger_spy) { double('Logger').as_null_object }
  let(:admin_set) do
    FactoryBot.create(:admin_set, title: ['Open_Access_Articles_and_Book_Chapters'])
  end
  let(:admin) { FactoryBot.create(:admin, uid: 'admin') }
  let(:permission_template) do
    FactoryBot.create(:permission_template, source_id: admin_set.id)
  end
  let(:workflow) do
    FactoryBot.create(:workflow, permission_template_id: permission_template.id, active: true)
  end
  let(:workflow_state) do
    FactoryBot.create(:workflow_state, workflow_id: workflow.id, name: 'deposited')
  end
  let(:visibility) { Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE }

  let(:config) do
    {
      'file_retrieval_directory' => Rails.root.join('spec/fixtures/files'),
      'output_dir' => Rails.root.join('tmp'),
      'depositor_onyen' => admin.uid,
      'admin_set_title' => admin_set.title.first
    }
  end

  let(:service) { described_class.new(config) }
  let(:mock_pubmed_service) { instance_double(Tasks::PubmedIngest::PubmedBacklogIngestService) }
  let(:mock_attachment_results) do
    {
      skipped: [],
      successfully_attached: [],
      successfully_ingested: [],
      failed: [],
      time: Time.now,
      depositor: admin.uid,
      file_retrieval_directory: Rails.root.join('spec/fixtures/files').to_s,
      output_dir: Rails.root.join('tmp').to_s,
      admin_set: admin_set.title.first,
      counts: {
        total_files: 2,
        skipped: 0,
        successfully_attached: 0,
        successfully_ingested: 0,
        failed: 0
      }
    }
  end

  before do
    allow(Rails).to receive(:logger).and_return(logger_spy)
    admin_set
    permission_template
    workflow
    workflow_state

    # Mock file system operations
    allow(Dir).to receive(:entries).with(Rails.root.join('spec/fixtures/files')).and_return(['.', '..', 'sample_pdf.pdf', 'test_article.pdf'])
    allow(File).to receive(:directory?).and_return(false)
    allow(File).to receive(:directory?).with(Rails.root.join('spec/fixtures/files') + '/.').and_return(true)
    allow(File).to receive(:directory?).with(Rails.root.join('spec/fixtures/files') + '/..').and_return(true)

    # Mock AdminSet lookup
    allow(AdminSet).to receive(:where).with(title: admin_set.title.first).and_return([admin_set])

    # Mock PubmedBacklogIngestService
    allow(Tasks::PubmedIngest::PubmedBacklogIngestService).to receive(:new).and_return(mock_pubmed_service)
    allow(mock_pubmed_service).to receive(:attachment_results).and_return(mock_attachment_results)
    allow(mock_pubmed_service).to receive(:record_result)
    allow(mock_pubmed_service).to receive(:attach_pdf_for_existing_work)
    allow(mock_pubmed_service).to receive(:ingest_publications).and_return(mock_attachment_results)

    # Mock external services
    allow(ActiveFedora::SolrService).to receive(:get).and_return({ 'response' => { 'docs' => [] } })

    # Mock HTTParty for ID conversion API
    allow(HTTParty).to receive(:get)

    # Mock file operations
    allow(File).to receive(:open).and_yield(double('file', write: nil))

    # Mock mailer
    mock_mailer = double('mailer', deliver_now: nil)
    allow(Tasks::PubmedIngest::PubmedReportingService).to receive(:generate_report).and_return('test report')
    allow(PubmedReportMailer).to receive(:pubmed_report_email).and_return(mock_mailer)

    # Stub virus checking
    allow(Hyrax::VirusCheckerService).to receive(:file_has_virus?) { false }

    # Stub longleaf job
    allow(RegisterToLongleafJob).to receive(:perform_later).and_return(nil)

    # Stub FITS characterization
    allow(CharacterizeJob).to receive(:perform_later)
  end

  describe '#initialize' do
    let(:valid_config) do
      {
        'file_retrieval_directory' => Rails.root.join('spec/fixtures/files'),
        'output_dir' => Rails.root.join('tmp'),
        'depositor_onyen' => admin.uid,
        'admin_set_title' => admin_set.title.first
      }
    end

    it 'successfully initializes with a valid config' do
      service = described_class.new(valid_config)
      expect(service).to be_a(Tasks::PubmedIngest::PubmedBacklogIngestCoordinatorService)
    end

    it 'sets up the service with correct configuration' do
      expected_file_retrieval_dir = Pathname.new(Rails.root.join('spec/fixtures/files'))
      expected_output_dir = Pathname.new(Rails.root.join('tmp'))
      expect(service.instance_variable_get(:@config)).to eq(config)
      expect(service.instance_variable_get(:@file_retrieval_directory)).to eq(expected_file_retrieval_dir)
      expect(service.instance_variable_get(:@output_dir)).to eq(expected_output_dir)
      expect(service.instance_variable_get(:@depositor_onyen)).to eq(admin.uid)
    end

    it 'initializes results hash with correct structure' do
      results = service.instance_variable_get(:@results)
      expect(results).to include(:skipped, :successfully_attached, :successfully_ingested, :failed)
      expect(results[:counts][:total_files]).to eq(2)
      expect(results[:depositor]).to eq(admin.uid)
      expect(results[:admin_set]).to eq(admin_set.title.first)
    end

    it 'creates PubmedBacklogIngestService with correct parameters' do
      service = described_class.new(valid_config)
      expected_path = Pathname.new(Rails.root.join('spec/fixtures/files'))
      expect(Tasks::PubmedIngest::PubmedBacklogIngestService).to have_received(:new).with(
        hash_including(
          'admin_set_title' => admin_set.title.first,
          'depositor_onyen' => admin.uid,
          'file_retrieval_directory' => expected_path
        )
      )
    end
  end

  describe '#run' do
    it 'executes all main steps and returns results' do
      expect(service).to receive(:process_file_matches).ordered
      expect(service).to receive(:attach_remaining_pdfs).ordered
      expect(service).to receive(:write_results_to_file).ordered
      expect(service).to receive(:finalize_report_and_notify).ordered

      result = service.run
      expect(result).to eq(mock_attachment_results)
    end
  end

  describe '#process_file_matches' do
    let(:alternate_ids) { { pmid: '12345', pmcid: 'PMC67890', doi: '10.1234/test' } }
    let(:xml_response) do
      <<~XML
        <?xml version="1.0"?>
        <pmcids>
          <record pmid="12345" pmcid="PMC67890" doi="10.1234/test" status="ok"/>
        </pmcids>
      XML
    end

    before do
      allow(HTTParty).to receive(:get).and_return(double('response', body: xml_response))
      allow(service).to receive(:find_best_work_match).and_return(nil)
    end

    it 'processes all files in directory' do
      expect(service).to receive(:retrieve_alternate_ids).with('sample_pdf').ordered
      expect(service).to receive(:retrieve_alternate_ids).with('test_article').ordered

      service.send(:process_file_matches)
    end

    context 'when work already has files attached' do
      let(:work) do
        FactoryBot.create(:article, title: ['Sample Work Title'], admin_set_id: admin_set.id)
      end
      let(:work_data) do
        {
          'id' => 'test_work_id',
          'has_model_ssim' => ['Article'],
          'title_tesim' => ['Sample Work Title'],
          'admin_set_tesim' => [admin_set.title.first],
          'file_set_ids_ssim' => ['fileset1']
        }
      end
      let(:admin_set_data) { { 'id' => admin_set.id } }

      before do
        allow(ActiveFedora::SolrService).to receive(:get)
          .with(/identifier_tesim/, anything)
          .and_return({ 'response' => { 'docs' => [work_data] } })
        allow(ActiveFedora::SolrService).to receive(:get)
          .with(/title_tesim.*AdminSet/, anything)
          .and_return({ 'response' => { 'docs' => [admin_set_data] } })
      end

      it 'skips the file' do
        expect(service).to receive(:log_and_label_skip).with(
          'test_article', 'pdf', alternate_ids, 'Already encountered this work during current run. Identifiers: ' + alternate_ids.to_s
        )

        service.send(:process_file_matches)
      end
    end

    context 'when work exists but no files attached' do
      let(:work_id) { 'test_work_id' }
      let(:work_data) do
        {
          'id' => work_id,
          'has_model_ssim' => ['Article'],
          'title_tesim' => ['Sample Work Title'],
          'admin_set_tesim' => [admin_set.title.first],
          'file_set_ids_ssim' => []
        }
      end
      let(:admin_set_data) { { 'id' => admin_set.id } }
      let(:article) { { id: work_id, title: 'Sample Work Title', admin_set_id: admin_set.id } }


      before do
        allow(ActiveFedora::SolrService).to receive(:get)
          .with(/identifier_tesim/, anything)
          .and_return({ 'response' => { 'docs' => [work_data] } })
        allow(ActiveFedora::SolrService).to receive(:get)
          .with(/title_tesim.*AdminSet/, anything)
          .and_return({ 'response' => { 'docs' => [admin_set_data] } })
        allow(WorkUtilsHelper).to receive(:fetch_model_instance).and_return(article)
      end

      it 'attempts to attach PDF to existing work' do
        match = {
          work_id: work_id,
          work_type: 'Article',
          file_set_names: []
        }

        allow(service).to receive(:find_best_work_match).and_return(match)

        expect(mock_pubmed_service).to receive(:attach_pdf_for_existing_work).with(
          match, Rails.root.join('spec/fixtures/files/sample_pdf.pdf').to_s, admin.uid
        )

        expect(mock_pubmed_service).to receive(:record_result).with(
          category: :successfully_attached,
          file_name: 'sample_pdf.pdf',
          message: 'Success',
          ids: alternate_ids,
          article: article
        )

        service.send(:process_file_matches)
      end
    end

    context 'when no match found' do
      it 'records as skipped for later ingestion' do
        expect(mock_pubmed_service).to receive(:record_result).with(
          category: :skipped,
          file_name: 'sample_pdf.pdf',
          message: 'Skipped: No CDR URL',
          ids: alternate_ids
        )

        service.send(:process_file_matches)
      end
    end

    context 'when error occurs during processing' do
      before do
        allow(service).to receive(:retrieve_alternate_ids).and_raise(StandardError.new('Test failure in retrieve_alternate_ids'))
      end

      it 'handles error gracefully and continues' do
        expect(logger_spy).to receive(:error).with(/Error processing file/)
        expect { service.send(:process_file_matches) }.not_to raise_error
      end
    end
  end

  describe '#attach_remaining_pdfs' do
    context 'when there are skipped items' do
      before do
        mock_attachment_results[:skipped] = [
          { 'file_name' => 'sample_pdf.pdf', 'pmid' => '12345', 'pdf_attached' => 'Skipped: No CDR URL' }
        ]
      end

      it 'calls ingest_publications on pubmed service' do
        expect(mock_pubmed_service).to receive(:ingest_publications)
        service.send(:attach_remaining_pdfs)
      end
    end

    context 'when no skipped items' do
      it 'logs info message and returns early' do
        expect(logger_spy).to receive(:info).with(/No skipped items to ingest/)
        expect(mock_pubmed_service).not_to receive(:ingest_publications)

        service.send(:attach_remaining_pdfs)
      end
    end

    context 'when error occurs during ingestion' do
      before do
        mock_attachment_results[:skipped] = [
          { 'file_name' => 'sample_pdf.pdf', 'pmid' => '12345', 'pdf_attached' => 'Skipped: No CDR URL' }
        ]
        allow(mock_pubmed_service).to receive(:ingest_publications).and_raise(StandardError.new('Ingest error'))
        allow(service).to receive(:double_log).and_call_original
      end

      it 'handles error gracefully' do
        expect(logger_spy).to receive(:error).with(/Error during PDF ingestion: Ingest error/)
        expect(logger_spy).to receive(:error).with(/Backtrace:/)
        service.send(:attach_remaining_pdfs)
      end
    end
  end

  describe '#write_results_to_file' do
    it 'writes JSON results to file' do
      expect(File).to receive(:open).with(satisfy { |arg|
                                            arg.is_a?(Pathname) && arg.basename.to_s.match?(/pdf_attachment_results_\d{14}\.json/)
                                          }, 'w').and_yield(double('file', write: nil))

      service.send(:write_results_to_file)
    end

    it 'logs summary of results' do
      expect(logger_spy).to receive(:info).with(/Results written to/)
      expect(logger_spy).to receive(:info).with(/Ingested: .*, Attached: .*, Failed: .*, Skipped: .*/)

      service.send(:write_results_to_file)
    end
  end

  describe '#finalize_report_and_notify' do
    it 'generates report and sends email' do
      expect(Tasks::PubmedIngest::PubmedReportingService).to receive(:generate_report).with(mock_attachment_results)
      expect(PubmedReportMailer).to receive(:pubmed_report_email).with('test report')

      service.send(:finalize_report_and_notify)
    end

    context 'when email sending fails' do
      before do
        allow(PubmedReportMailer).to receive(:pubmed_report_email).and_raise(StandardError.new('Email error'))
        allow(service).to receive(:double_log).and_call_original
      end

      it 'handles error gracefully' do
        expect(logger_spy).to receive(:error).with(/Failed to send email/)
        expect(logger_spy).to receive(:error).with(/Backtrace:/)
        service.send(:finalize_report_and_notify)
      end
    end
  end

  describe '#find_best_work_match' do
    let(:alternate_ids) { { pmid: '12345', pmcid: 'PMC67890', doi: '10.1234/test' } }
    let(:work_data) do
      {
        'id' => 'test_work_id',
        'has_model_ssim' => ['Article'],
        'title_tesim' => ['Test Article'],
        'admin_set_tesim' => [admin_set.title.first],
        'file_set_ids_ssim' => ['fileset1']
      }
    end
    let(:admin_set_data) { { 'id' => admin_set.id } }

    before do
      allow(ActiveFedora::SolrService).to receive(:get)
        .with(/identifier_tesim/, anything)
        .and_return({ 'response' => { 'docs' => [work_data] } })
      allow(ActiveFedora::SolrService).to receive(:get)
        .with(/title_tesim.*AdminSet/, anything)
        .and_return({ 'response' => { 'docs' => [admin_set_data] } })
    end

    it 'returns work match data when found' do
      result = service.send(:find_best_work_match, alternate_ids)

      expect(result).to include(
        work_id: 'test_work_id',
        file_set_ids: ['fileset1'],
        admin_set_name: 'Open_Access_Articles_and_Book_Chapters',
        admin_set_id: admin_set.id,
        work_type: 'Article',
        title: 'Test Article'
      )
    end

    it 'tries DOI first, then PMCID, then PMID' do
      expect(ActiveFedora::SolrService).to receive(:get)
        .with('identifier_tesim:"10.1234/test" NOT has_model_ssim:("FileSet")', anything).ordered
        .and_return({ 'response' => { 'docs' => [] } })
      expect(ActiveFedora::SolrService).to receive(:get)
        .with('identifier_tesim:"PMC67890" NOT has_model_ssim:("FileSet")', anything).ordered
        .and_return({ 'response' => { 'docs' => [work_data] } })

      service.send(:find_best_work_match, alternate_ids)
    end

    it 'returns nil when no match found' do
      allow(ActiveFedora::SolrService).to receive(:get).and_return({ 'response' => { 'docs' => [] } })

      result = service.send(:find_best_work_match, alternate_ids)
      expect(result).to be_nil
    end
  end

  describe '#retrieve_alternate_ids' do
    let(:xml_response) do
      <<~XML
        <?xml version="1.0"?>
        <pmcids>
          <record pmid="12345" pmcid="PMC67890" doi="10.1234/test" status="ok"/>
        </pmcids>
      XML
    end

    before do
      allow(HTTParty).to receive(:get).and_return(double('response', body: xml_response))
    end

    it 'returns alternate IDs from API response' do
      result = service.send(:retrieve_alternate_ids, '12345')

      expect(result).to eq({
        pmid: '12345',
        pmcid: 'PMC67890',
        doi: '10.1234/test'
      })
    end

    context 'when API returns error status' do
      let(:error_xml) do
        <<~XML
          <?xml version="1.0"?>
          <pmcids>
            <record status="error"/>
          </pmcids>
        XML
      end

      before do
        allow(HTTParty).to receive(:get).and_return(double('response', body: error_xml))
      end

      it 'falls back to identifier-based hash' do
        result = service.send(:retrieve_alternate_ids, 'PMC12345')
        expect(result).to eq({ pmcid: 'PMC12345' })
      end
    end

    context 'when HTTP request fails' do
      before do
        allow(HTTParty).to receive(:get).and_raise(StandardError.new('Network error'))
        expect(logger_spy).to receive(:warn)
      end

      it 'falls back to identifier-based hash' do
        result = service.send(:retrieve_alternate_ids, '12345')
        expect(result).to eq({ pmid: '12345' })
      end
    end
  end

  describe '#fallback_id_hash' do
    it 'returns PMCID hash for PMC identifiers' do
      result = service.send(:fallback_id_hash, 'PMC12345')
      expect(result).to eq({ pmcid: 'PMC12345' })
    end

    it 'returns PMID hash for non-PMC identifiers' do
      result = service.send(:fallback_id_hash, '12345')
      expect(result).to eq({ pmid: '12345' })
    end
  end

  describe '#has_matching_ids?' do
    let(:existing) { { pmid: '12345', pmcid: 'PMC67890', doi: '10.1234/test' } }
    let(:current) { { pmid: '12345', pmcid: 'PMC99999', doi: '10.9999/other' } }

    it 'returns true when any ID matches' do
      result = service.send(:has_matching_ids?, existing, current)
      expect(result).to be true
    end

    it 'returns false when no IDs match' do
      different = { pmid: '99999', pmcid: 'PMC11111', doi: '10.1111/different' }
      result = service.send(:has_matching_ids?, existing, different)
      expect(result).to be false
    end
  end

  describe '#retrieve_filenames' do
    let(:test_pathname) { Pathname.new('spec/fixtures/files') }

    before do
      allow(Pathname).to receive(:new).and_call_original
      allow(Pathname).to receive(:new).with('spec/fixtures/files').and_return(test_pathname)
      allow(test_pathname).to receive(:absolute?).and_return(true)

      allow(Dir).to receive(:entries).with(test_pathname).and_return(['.', '..', 'file1.pdf', 'file2.txt', 'file1.pdf'])
      allow(File).to receive(:directory?).with(test_pathname.join('.')).and_return(true)
      allow(File).to receive(:directory?).with(test_pathname.join('..')).and_return(true)
      allow(File).to receive(:directory?).with(test_pathname.join('file1.pdf')).and_return(false)
      allow(File).to receive(:directory?).with(test_pathname.join('file2.txt')).and_return(false)
    end

    context 'with absolute path' do
      let(:absolute_pathname) { Pathname.new('/absolute/path') }

      it 'uses path as-is' do
        allow(Pathname).to receive(:new).with('/absolute/path').and_return(absolute_pathname)
        allow(absolute_pathname).to receive(:absolute?).and_return(true)

        allow(Dir).to receive(:entries).with('/absolute/path').and_return(['.', '..', 'test.pdf'])
        allow(File).to receive(:directory?).with(absolute_pathname.join('.')).and_return(true)
        allow(File).to receive(:directory?).with(absolute_pathname.join('..')).and_return(true)
        allow(File).to receive(:directory?).with(absolute_pathname.join('test.pdf')).and_return(false)

        result = service.send(:retrieve_filenames, '/absolute/path')
        expect(result).to eq([['test', 'pdf']])
      end
    end

    context 'with relative path' do
      let(:relative_pathname) { Pathname.new('relative/path') }

      it 'joins with Rails root' do
        allow(Pathname).to receive(:new).with('relative/path').and_return(relative_pathname)
        allow(relative_pathname).to receive(:absolute?).and_return(false)

        full_path = Rails.root.join('relative/path')
        allow(Dir).to receive(:entries).with(full_path).and_return(['.', '..', 'test.pdf'])
        allow(File).to receive(:directory?).with(full_path.join('test.pdf')).and_return(false)
        allow(File).to receive(:directory?).with(full_path.join('.')).and_return(true)
        allow(File).to receive(:directory?).with(full_path.join('..')).and_return(true)

        result = service.send(:retrieve_filenames, 'relative/path')
        expect(result).to eq([['test', 'pdf']])
      end
    end

    it 'filters out directories and returns sorted unique filename pairs' do
      result = service.send(:retrieve_filenames, test_pathname)
      expect(result).to eq([['file1', 'pdf'], ['file2', 'txt']])
    end
  end


  describe '#double_log' do
    it 'logs to both puts and Rails logger with tag' do
      expect { service.send(:double_log, 'test message') }.to output("[Coordinator] test message\n").to_stdout
      expect(logger_spy).to have_received(:info).with('[Coordinator] test message')
    end

    it 'respects log level parameter' do
      service.send(:double_log, 'warning message', :warn)
      expect(logger_spy).to have_received(:warn).with('[Coordinator] warning message')
    end

    it 'handles error level logging' do
      service.send(:double_log, 'error message', :error)
      expect(logger_spy).to have_received(:error).with('[Coordinator] error message')
    end
  end
end
