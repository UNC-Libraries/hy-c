# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tasks::PubmedIngest::Recurring::PubmedIngestCoordinatorService do
  let(:config) do
    {
        'depositor_onyen' => 'test_user',
        'output_dir'      => '/tmp/test_output',
        'full_text_dir'   => '/tmp/test_fulltext',
        'admin_set_title' => 'default',
        'start_date'      => Date.parse('2024-01-01'),
        'end_date'        => Date.parse('2024-01-31'),
        'time'            => Time.now,
    }
  end
  let(:tracker) do
    data = {
        'start_time'   => config['time'].strftime('%Y-%m-%d %H:%M:%S'),
        'restart_time' => nil,
        'date_range'   => {
          'start' => config['start_date'].strftime('%Y-%m-%d'),
          'end'   => config['end_date'].strftime('%Y-%m-%d')
        },
        'admin_set_title' => config['admin_set_title'],
        'depositor_onyen' => config['depositor_onyen'],
        'output_dir'      => config['output_dir'],
        'full_text_dir'   => config['full_text_dir'],
        'progress' => {
          'retrieve_ids_within_date_range' => {
            'pubmed' => { 'cursor' => 0, 'completed' => false },
            'pmc'    => { 'cursor' => 0, 'completed' => false }
          },
          'stream_and_write_alternate_ids' => {
            'pubmed' => { 'cursor' => 0, 'completed' => false },
            'pmc'    => { 'cursor' => 0, 'completed' => false }
          },
          'adjust_id_lists' => {
            'completed' => false,
            'pubmed' => { 'original_size' => 0, 'adjusted_size' => 0 },
            'pmc'    => { 'original_size' => 0, 'adjusted_size' => 0 }
          },
          'metadata_ingest' => {
            'pubmed' => { 'cursor' => 0, 'completed' => false },
            'pmc'    => { 'cursor' => 0, 'completed' => false }
          },
          'attach_files_to_works' => { 'completed' => false },
          'send_summary_email'    => { 'completed' => false }
        }
      }

    obj = Object.new
    obj.define_singleton_method(:[])   { |k| data[k] }
    obj.define_singleton_method(:[]=)  { |k, v| data[k] = v }
    obj.define_singleton_method(:save) { true }   # no-op for tests
    obj.define_singleton_method(:to_h) { data }
    obj
  end


  let(:service) { described_class.new(config, tracker) }

  let(:mock_id_retrieval_service) { double('id_retrieval_service') }
  let(:mock_metadata_ingest_service) { double('metadata_ingest_service') }
  let(:mock_file_attachment_service) { double('file_attachment_service') }
  let(:mock_mailer) { double('mailer', deliver_now: true) }

  before do
    allow(LogUtilsHelper).to receive(:double_log)
    allow(Rails.logger).to receive(:error)
    allow(File).to receive(:exist?).and_return(false)
    allow(File).to receive(:join).and_call_original
    allow(FileUtils).to receive(:mkdir_p)
    allow(JsonFileUtilsHelper).to receive(:write_json)
    allow(JsonFileUtilsHelper).to receive(:read_jsonl).and_return([])
    allow(WorkUtilsHelper).to receive(:fetch_work_data_by_id)
    allow(WorkUtilsHelper).to receive(:generate_cdr_url_for_work_id)
    allow(Tasks::PubmedIngest::SharedUtilities::PubmedReportingService).to receive(:generate_report)
    allow(PubmedReportMailer).to receive(:pubmed_report_email).and_return(mock_mailer)

    # Mock service instantiation
    allow(Tasks::PubmedIngest::Recurring::Utilities::IdRetrievalService)
      .to receive(:new).and_return(mock_id_retrieval_service)
    allow(Tasks::PubmedIngest::Recurring::Utilities::MetadataIngestService)
      .to receive(:new).and_return(mock_metadata_ingest_service)
    allow(Tasks::PubmedIngest::Recurring::Utilities::FileAttachmentService)
      .to receive(:new).and_return(mock_file_attachment_service)

    allow(Tasks::PubmedIngest::SharedUtilities::PubmedReportingService)
    .to receive(:generate_report)
    .and_return({ headers: { total_unique_records: 0 }, summary: 'Test report' })

    # Mock service methods
    allow(mock_id_retrieval_service).to receive(:retrieve_ids_within_date_range)
    allow(mock_id_retrieval_service).to receive(:stream_and_write_alternate_ids)
    allow(mock_id_retrieval_service).to receive(:adjust_id_lists)
    allow(mock_metadata_ingest_service).to receive(:load_alternate_ids_from_file)
    allow(mock_metadata_ingest_service).to receive(:batch_retrieve_and_process_metadata)
    allow(mock_file_attachment_service).to receive(:run)

    # Set up output directories
    output_dir = config['output_dir']
    FileUtils.mkdir_p(File.join(output_dir, '01_build_id_lists'))
    FileUtils.mkdir_p(File.join(output_dir, '02_load_and_ingest_metadata'))
    FileUtils.mkdir_p(File.join(output_dir, '03_attach_files_to_works'))
    FileUtils.mkdir_p(config['full_text_dir'])
  end

  describe '#initialize' do
    it 'sets up instance variables correctly' do
      expect(service.instance_variable_get(:@config)).to eq(config)
      expect(service.instance_variable_get(:@tracker)).to eq(tracker)
      expect(service.instance_variable_get(:@depositor_onyen)).to eq('test_user')
      expect(service.instance_variable_get(:@output_dir)).to eq('/tmp/test_output')
      expect(service.instance_variable_get(:@full_text_dir)).to eq('/tmp/test_fulltext')
      expect(service.instance_variable_get(:@admin_set_title)).to eq('default')
      expect(service.instance_variable_get(:@start_date)).to eq(Date.parse('2024-01-01'))
      expect(service.instance_variable_get(:@end_date)).to eq(Date.parse('2024-01-31'))
    end

    it 'initializes results hash with correct structure' do
      results = service.instance_variable_get(:@results)

      expect(results).to have_key(:skipped)
      expect(results).to have_key(:successfully_attached)
      expect(results).to have_key(:successfully_ingested)
      expect(results).to have_key(:failed)
      expect(results).to have_key(:counts)
      expect(results).to have_key(:headers)
      expect(results[:depositor]).to eq('test_user')
      expect(results[:admin_set]).to eq('default')
      expect(results[:output_dir]).to eq('/tmp/test_output')
      expect(results[:full_text_dir]).to eq('/tmp/test_fulltext')
      expect(results[:start_date]).to eq('2024-01-01')
      expect(results[:end_date]).to eq('2024-01-31')
    end

    it 'sets up output directories correctly' do
      id_list_dir = service.instance_variable_get(:@id_list_output_directory)
      metadata_dir = service.instance_variable_get(:@metadata_ingest_output_directory)
      attachment_dir = service.instance_variable_get(:@attachment_output_directory)

      expect(id_list_dir).to eq('/tmp/test_output/01_build_id_lists')
      expect(metadata_dir).to eq('/tmp/test_output/02_load_and_ingest_metadata')
      expect(attachment_dir).to eq('/tmp/test_output/03_attach_files_to_works')
    end

    it 'creates output directories if they do not exist' do
      expect(FileUtils).to have_received(:mkdir_p).with('/tmp/test_output/01_build_id_lists')
      expect(FileUtils).to have_received(:mkdir_p).with('/tmp/test_output/02_load_and_ingest_metadata')
      expect(FileUtils).to have_received(:mkdir_p).with('/tmp/test_output/03_attach_files_to_works')
    end
  end

  describe '#run' do
    let(:sample_results) do
      [
        {
          'category' => 'successfully_attached',
          'work_id' => 'work_123',
          'message' => 'File attached successfully',
          'ids' => { 'pmid' => '123456', 'pmcid' => 'PMC789012' },
          'file_name' => 'PMC789012_001.pdf'
        }
      ]
    end

    before do
      allow(File).to receive(:exist?).with(/attachment_results\.jsonl/).and_return(true)
      allow(JsonFileUtilsHelper).to receive(:read_jsonl).with(/attachment_results\.jsonl/).and_return(sample_results)
      allow(WorkUtilsHelper).to receive(:generate_cdr_url_for_work_id).with('work_123').and_return('http://example.com/work_123')
      allow(Tasks::PubmedIngest::SharedUtilities::PubmedReportingService).to receive(:generate_report).and_return({
        headers: { total_unique_records: 0 },
        summary: 'Test report'
      })
    end

    it 'executes all workflow steps in correct order' do
      expect(service).to receive(:build_id_lists).ordered
      expect(service).to receive(:load_and_ingest_metadata).ordered
      expect(service).to receive(:attach_files).ordered
      expect(service).to receive(:load_results).ordered
      expect(service).to receive(:finalize_report_and_notify).ordered

      service.run
    end

    it 'writes final results to JSON file' do
      service.run

      expect(JsonFileUtilsHelper).to have_received(:write_json).with(
        service.instance_variable_get(:@results),
        '/tmp/test_output/ingest_results.json',
        pretty: true
      )
    end

    it 'logs workflow completion' do
      service.run

      expect(LogUtilsHelper).to have_received(:double_log).with(
        'PubMed ingest workflow completed successfully.',
        :info,
        tag: 'PubmedIngestCoordinator'
      )
    end

    context 'when an error occurs during workflow' do
      before do
        allow(service).to receive(:build_id_lists).and_raise(StandardError.new('Test error'))
      end

      it 'logs the error and re-raises' do
        expect {
          service.run
        }.to raise_error('Test error')

        expect(LogUtilsHelper).to have_received(:double_log).with(
          /PubMed ingest workflow failed: Test error/,
          :error,
          tag: 'PubmedIngestCoordinator'
        )
      end
    end
  end

  describe '#build_id_lists' do
    it 'creates IdRetrievalService with correct parameters' do
      service.send(:build_id_lists)

      expect(Tasks::PubmedIngest::Recurring::Utilities::IdRetrievalService)
        .to have_received(:new).with(
          start_date: Date.parse('2024-01-01'),
          end_date: Date.parse('2024-01-31'),
          tracker: tracker
        )
    end

    it 'retrieves IDs for both pubmed and pmc databases' do
      service.send(:build_id_lists)

      expect(mock_id_retrieval_service).to have_received(:retrieve_ids_within_date_range).with(
        output_path: '/tmp/test_output/01_build_id_lists/pubmed_ids.jsonl',
        db: 'pubmed'
      )
      expect(mock_id_retrieval_service).to have_received(:retrieve_ids_within_date_range).with(
        output_path: '/tmp/test_output/01_build_id_lists/pmc_ids.jsonl',
        db: 'pmc'
      )
    end

    it 'streams and writes alternate IDs for both databases' do
      service.send(:build_id_lists)

      expect(mock_id_retrieval_service).to have_received(:stream_and_write_alternate_ids).with(
        input_path: '/tmp/test_output/01_build_id_lists/pubmed_ids.jsonl',
        output_path: '/tmp/test_output/01_build_id_lists/pubmed_alternate_ids.jsonl',
        db: 'pubmed'
      )
      expect(mock_id_retrieval_service).to have_received(:stream_and_write_alternate_ids).with(
        input_path: '/tmp/test_output/01_build_id_lists/pmc_ids.jsonl',
        output_path: '/tmp/test_output/01_build_id_lists/pmc_alternate_ids.jsonl',
        db: 'pmc'
      )
    end

    it 'adjusts ID lists and updates tracker' do
      service.send(:build_id_lists)

      expect(mock_id_retrieval_service).to have_received(:adjust_id_lists).with(
        pubmed_path: '/tmp/test_output/01_build_id_lists/pubmed_alternate_ids.jsonl',
        pmc_path: '/tmp/test_output/01_build_id_lists/pmc_alternate_ids.jsonl'
      )
    end

    context 'when ID retrieval is already completed' do
      before do
        tracker['progress']['retrieve_ids_within_date_range']['pubmed']['completed'] = true
        tracker['progress']['retrieve_ids_within_date_range']['pmc']['completed'] = true
      end

      it 'skips ID retrieval step' do
        service.send(:build_id_lists)

        expect(mock_id_retrieval_service).not_to have_received(:retrieve_ids_within_date_range)
        expect(LogUtilsHelper).to have_received(:double_log).with(
          'Skipping ID retrieval for pubmed as it is already completed.',
          :info,
          tag: 'build_id_lists'
        )
        expect(LogUtilsHelper).to have_received(:double_log).with(
          'Skipping ID retrieval for pmc as it is already completed.',
          :info,
          tag: 'build_id_lists'
        )
      end
    end

    context 'when alternate ID streaming is already completed' do
      before do
        tracker['progress']['stream_and_write_alternate_ids']['pubmed']['completed'] = true
        tracker['progress']['stream_and_write_alternate_ids']['pmc']['completed'] = true
      end

      it 'skips alternate ID streaming step' do
        service.send(:build_id_lists)

        expect(mock_id_retrieval_service).not_to have_received(:stream_and_write_alternate_ids)
        expect(LogUtilsHelper).to have_received(:double_log).with(
          'Skipping alternate ID retrieval for pubmed as it is already completed.',
          :info,
          tag: 'build_id_lists'
        )
        expect(LogUtilsHelper).to have_received(:double_log).with(
          'Skipping alternate ID retrieval for pmc as it is already completed.',
          :info,
          tag: 'build_id_lists'
        )
      end
    end

    it 'logs step completion' do
      service.send(:build_id_lists)

      expected_dir = service.instance_variable_get(:@id_list_output_directory)
      expect(LogUtilsHelper).to have_received(:double_log).with(
        "ID lists built successfully. Output directory: #{expected_dir}",
        :info,
        tag: 'build_id_lists'
      )
    end
  end

  describe '#load_and_ingest_metadata' do
    it 'creates MetadataIngestService with correct parameters' do
      service.send(:load_and_ingest_metadata)

      expect(Tasks::PubmedIngest::Recurring::Utilities::MetadataIngestService)
        .to have_received(:new).with(
          config: config,
          results: service.instance_variable_get(:@results),
          tracker: tracker,
          results_path: '/tmp/test_output/02_load_and_ingest_metadata/metadata_ingest_results.jsonl'
        )
    end

    it 'processes both pubmed and pmc databases' do
      service.send(:load_and_ingest_metadata)

      expect(mock_metadata_ingest_service).to have_received(:load_alternate_ids_from_file).with(
        path: '/tmp/test_output/01_build_id_lists/pubmed_alternate_ids.jsonl'
      )
      expect(mock_metadata_ingest_service).to have_received(:batch_retrieve_and_process_metadata).with(
        db: 'pubmed'
      )

      expect(mock_metadata_ingest_service).to have_received(:load_alternate_ids_from_file).with(
        path: '/tmp/test_output/01_build_id_lists/pmc_alternate_ids.jsonl'
      )
      expect(mock_metadata_ingest_service).to have_received(:batch_retrieve_and_process_metadata).with(
        db: 'pmc'
      )
    end

    it 'updates tracker completion status for each database' do
      expect(tracker['progress']['metadata_ingest']['pubmed']['completed']).to be false
      expect(tracker['progress']['metadata_ingest']['pmc']['completed']).to be false

      service.send(:load_and_ingest_metadata)

      expect(tracker['progress']['metadata_ingest']['pubmed']['completed']).to be true
      expect(tracker['progress']['metadata_ingest']['pmc']['completed']).to be true
    end

    context 'when metadata ingest is already completed for a database' do
      before do
        tracker['progress']['metadata_ingest']['pubmed']['completed'] = true
      end

      it 'skips completed database and processes remaining ones' do
        service.send(:load_and_ingest_metadata)

        expect(LogUtilsHelper).to have_received(:double_log).with(
          'Skipping metadata ingest for pubmed as it is already completed.',
          :info,
          tag: 'load_and_ingest_metadata'
        )

        # Still processes PMC
        expect(mock_metadata_ingest_service).to have_received(:load_alternate_ids_from_file).with(
          path: '/tmp/test_output/01_build_id_lists/pmc_alternate_ids.jsonl'
        )
      end
    end

    it 'logs step completion' do
      service.send(:load_and_ingest_metadata)

      expect(LogUtilsHelper).to have_received(:double_log).with(
        'Metadata ingest for pubmed completed successfully.',
        :info,
        tag: 'load_and_ingest_metadata'
     )
      expect(LogUtilsHelper).to have_received(:double_log).with(
         'Metadata ingest for pmc completed successfully.',
         :info,
         tag: 'load_and_ingest_metadata'
     )
    end

    context 'when metadata service raises an error' do
      before do
        allow(mock_metadata_ingest_service).to receive(:batch_retrieve_and_process_metadata)
          .and_raise(StandardError.new('Metadata processing failed'))
      end

      it 'logs the error and re-raises' do
        expect {
          service.send(:load_and_ingest_metadata)
        }.to raise_error('Metadata processing failed')

        expect(LogUtilsHelper).to have_received(:double_log).with(
          /Metadata ingest failed: Metadata processing failed/,
          :error,
          tag: 'load_and_ingest_metadata'
        )
      end
    end
  end

  describe '#attach_files' do
    it 'creates FileAttachmentService with correct parameters' do
      service.send(:attach_files)

      expect(Tasks::PubmedIngest::Recurring::Utilities::FileAttachmentService)
        .to have_received(:new).with(
          config: config,
          tracker: tracker,
          output_path: '/tmp/test_output/03_attach_files_to_works',
          full_text_path: '/tmp/test_fulltext',
          metadata_ingest_result_path: '/tmp/test_output/02_load_and_ingest_metadata/metadata_ingest_results.jsonl'
        )
    end

    it 'runs the file attachment service and updates tracker' do
      service.send(:attach_files)

      expect(mock_file_attachment_service).to have_received(:run)
      expect(tracker['progress']['attach_files_to_works']['completed']).to be true
    end

    context 'when file attachment is already completed' do
      before do
        tracker['progress']['attach_files_to_works']['completed'] = true
      end

      it 'skips file attachment step' do
        service.send(:attach_files)

        expect(mock_file_attachment_service).not_to have_received(:run)
        expect(LogUtilsHelper).to have_received(:double_log).with(
          'Skipping file attachment as it is already completed.',
          :info,
          tag: 'attach_files'
        )
      end
    end

    it 'logs step completion' do
      service.send(:attach_files)

      expect(LogUtilsHelper).to have_received(:double_log).with(
        'File attachment process completed.',
        :info,
        tag: 'attach_files'
      )
    end

    context 'when file attachment service raises an error' do
      before do
        allow(mock_file_attachment_service).to receive(:run)
          .and_raise(StandardError.new('Attachment failed'))
      end

      it 'logs the error and re-raises' do
        expect {
          service.send(:attach_files)
        }.to raise_error('Attachment failed')

        expect(LogUtilsHelper).to have_received(:double_log).with(
          /File attachment failed: Attachment failed/,
          :error,
          tag: 'attach_files'
        )
      end
    end
  end

  describe '#load_results' do
    let(:results_path) { '/tmp/test_output/03_attach_files_to_works/attachment_results.jsonl' }
    let(:sample_results) do
      [
        {
          'category' => 'successfully_attached',
          'work_id' => 'work_123',
          'message' => 'File attached successfully',
          'ids' => { 'pmid' => '123456', 'pmcid' => 'PMC789012' },
          'file_name' => 'PMC789012_001.pdf'
        },
        {
          'category' => 'failed',
          'work_id' => nil,
          'message' => 'File attachment failed',
          'ids' => { 'pmid' => '234567', 'pmcid' => 'PMC890123' },
          'file_name' => 'NONE'
        },
        {
          'category' => 'skipped',
          'work_id' => 'work_789',
          'message' => 'Already has files',
          'ids' => { 'pmid' => '345678', 'pmcid' => 'PMC901234' },
          'file_name' => 'NONE'
        }
      ]
    end

    before do
      allow(File).to receive(:exist?).with(results_path).and_return(true)
      allow(JsonFileUtilsHelper).to receive(:read_jsonl).with(results_path).and_return(sample_results)
      allow(WorkUtilsHelper).to receive(:generate_cdr_url_for_work_id).with('work_123').and_return('http://example.com/work_123')
      allow(WorkUtilsHelper).to receive(:generate_cdr_url_for_work_id).with('work_789').and_return('http://example.com/work_789')
    end

    it 'loads and formats results correctly' do
      service.send(:load_results)

      results = service.instance_variable_get(:@results)
      expect(results[:successfully_attached].size).to eq(1)
      expect(results[:failed].size).to eq(1)
      expect(results[:skipped].size).to eq(1)
      expect(results[:counts][:successfully_attached]).to eq(1)
      expect(results[:counts][:failed]).to eq(1)
      expect(results[:counts][:skipped]).to eq(1)
    end

    it 'transforms result structure correctly' do
      service.send(:load_results)

      results = service.instance_variable_get(:@results)
      attached_result = results[:successfully_attached].first

      expect(attached_result['pmid']).to eq('123456')
      expect(attached_result['pmcid']).to eq('PMC789012')
      expect(attached_result['work_id']).to eq('work_123')
      expect(attached_result['pdf_attached']).to eq('File attached successfully')
      expect(attached_result['file_name']).to eq('PMC789012_001.pdf')
      expect(attached_result['cdr_url']).to eq('http://example.com/work_123')
      expect(attached_result).not_to have_key('ids')
      expect(attached_result).not_to have_key('message')
    end

    it 'handles records without work_id correctly' do
      service.send(:load_results)

      results = service.instance_variable_get(:@results)
      failed_result = results[:failed].first

      expect(failed_result['pmid']).to eq('234567')
      expect(failed_result['pmcid']).to eq('PMC890123')
      expect(failed_result['work_id']).to be_nil
      expect(failed_result['file_name']).to eq('NONE')
      expect(failed_result).not_to have_key('cdr_url')
    end

    context 'when results file does not exist' do
      before do
        allow(File).to receive(:exist?).with(results_path).and_return(false)
      end

      it 'raises error with descriptive message' do
        expect {
          service.send(:load_results)
        }.to raise_error("Results file not found at #{results_path}")

        expect(LogUtilsHelper).to have_received(:double_log).with(
          "Results file not found at #{results_path}",
          :error,
          tag: 'load_and_format_results'
        )
      end
    end

    context 'when JSON parsing fails' do
      before do
        allow(File).to receive(:exist?).with(results_path).and_return(true)
        allow(JsonFileUtilsHelper).to receive(:read_jsonl).and_raise(JSON::ParserError.new('Invalid JSON'))
      end

      it 'raises error with descriptive message' do
        expect {
          service.send(:load_results)
        }.to raise_error(/Failed to load or parse results/)

        expect(LogUtilsHelper).to have_received(:double_log).with(
          /Failed to load or parse results.*Invalid JSON/,
          :error,
          tag: 'load_and_format_results'
        )
      end
    end

    it 'logs results loading completion' do
      service.send(:load_results)
      expected_dir = service.instance_variable_get(:@attachment_output_directory)

      expect(LogUtilsHelper).to have_received(:double_log).with(
        a_string_including("Successfully loaded and formatted results from #{expected_dir}/attachment_results.jsonl"),
        :info,
        tag: 'load_and_format_results'
      )
    end
  end

  describe '#format_results_for_reporting' do
    let(:raw_results) do
      [
        {
          'category' => 'successfully_ingested',
          'work_id' => 'work_456',
          'message' => 'Successfully ingested',
          'ids' => { 'pmid' => '345678', 'pmcid' => 'PMC901234', 'doi' => '10.1000/example' },
          'file_name' => 'NONE'
        },
        {
          'category' => 'skipped',
          'work_id' => nil,
          'message' => 'Already exists',
          'ids' => { 'pmid' => '456789' },
          'file_name' => 'NONE'
        },
        {
          'category' => 'invalid_category',
          'message' => 'Should be ignored',
          'ids' => { 'pmid' => '999999' },
          'file_name' => 'NONE'
        }
      ]
    end

    before do
      allow(WorkUtilsHelper).to receive(:generate_cdr_url_for_work_id).with('work_456').and_return('http://example.com/work_456')
    end

    it 'formats valid categories correctly' do
      service.send(:format_results_for_reporting, raw_results)

      results = service.instance_variable_get(:@results)

      expect(results[:successfully_ingested].size).to eq(1)
      expect(results[:skipped].size).to eq(1)
      expect(results[:counts][:successfully_ingested]).to eq(1)
      expect(results[:counts][:skipped]).to eq(1)
    end

    it 'ignores invalid categories' do
      service.send(:format_results_for_reporting, raw_results)

      results = service.instance_variable_get(:@results)

      expect(results).not_to have_key(:invalid_category)
    end

    it 'merges IDs into main entry and transforms field names' do
      service.send(:format_results_for_reporting, raw_results)

      results = service.instance_variable_get(:@results)
      ingested_entry = results[:successfully_ingested].first

      expect(ingested_entry['pmid']).to eq('345678')
      expect(ingested_entry['pmcid']).to eq('PMC901234')
      expect(ingested_entry['doi']).to eq('10.1000/example')
      expect(ingested_entry['work_id']).to eq('work_456')
      expect(ingested_entry['pdf_attached']).to eq('Successfully ingested')
      expect(ingested_entry['file_name']).to eq('NONE')
      expect(ingested_entry['cdr_url']).to eq('http://example.com/work_456')
    end

    it 'handles entries without work_id correctly' do
      service.send(:format_results_for_reporting, raw_results)

      results = service.instance_variable_get(:@results)
      skipped_entry = results[:skipped].first

      expect(skipped_entry['pmid']).to eq('456789')
      expect(skipped_entry['work_id']).to be_nil
      expect(skipped_entry).not_to have_key('cdr_url')
    end
  end

  describe '#finalize_report_and_notify' do
    let(:mock_report) do
      {
        headers: { total_unique_records: 0 },
        summary: 'Test report'
      }
    end

    before do
      allow(Tasks::PubmedIngest::SharedUtilities::PubmedReportingService)
        .to receive(:generate_report).and_return(mock_report)
    end

    it 'generates report and sends email' do
      results = service.instance_variable_get(:@results)
      results[:counts][:successfully_ingested] = 5
      results[:counts][:successfully_attached] = 3
      results[:counts][:skipped] = 2

      service.send(:finalize_report_and_notify, results)

      expect(Tasks::PubmedIngest::SharedUtilities::PubmedReportingService)
        .to have_received(:generate_report).with(results)
      expect(mock_report[:headers][:total_unique_records]).to eq(10)
      expect(PubmedReportMailer).to have_received(:pubmed_report_email).with(mock_report)
      expect(mock_mailer).to have_received(:deliver_now)
      expect(tracker['progress']['send_summary_email']['completed']).to be true
    end

    context 'when email notification already completed' do
      before do
        tracker['progress']['send_summary_email']['completed'] = true
      end

      it 'skips email sending' do
        service.send(:finalize_report_and_notify, {})

        expect(PubmedReportMailer).not_to have_received(:pubmed_report_email)
        expect(LogUtilsHelper).to have_received(:double_log).with(
          'Skipping email notification as it has already been sent.',
          :info,
          tag: 'send_summary_email'
        )
      end
    end

    context 'when email sending fails' do
      before do
        allow(PubmedReportMailer).to receive(:pubmed_report_email).and_raise(StandardError.new('Email failed'))
      end

      it 'logs error and continues' do
        expect {
          service.send(:finalize_report_and_notify, {})
        }.not_to raise_error

        expect(LogUtilsHelper).to have_received(:double_log).with(
          'Failed to send email notification: Email failed',
          :error,
          tag: 'send_summary_email'
        )
      end
    end
  end

  describe 'workflow integration' do
    it 'maintains proper tracker state throughout workflow' do
      # Start with all steps incomplete
      expect(tracker['progress']['retrieve_ids_within_date_range']['pubmed']['completed']).to be false
      expect(tracker['progress']['metadata_ingest']['pubmed']['completed']).to be false
      expect(tracker['progress']['attach_files_to_works']['completed']).to be false
      expect(tracker['progress']['send_summary_email']['completed']).to be false

      # Mock files for load_results
      allow(File).to receive(:exist?).with(/attachment_results\.jsonl/).and_return(true)
      allow(JsonFileUtilsHelper).to receive(:read_jsonl).and_return([])

      service.run

      # After completion, all steps complete
      expect(tracker['progress']['retrieve_ids_within_date_range']['pubmed']['completed']).to be true
      expect(tracker['progress']['retrieve_ids_within_date_range']['pmc']['completed']).to be true
      expect(tracker['progress']['stream_and_write_alternate_ids']['pubmed']['completed']).to be true
      expect(tracker['progress']['stream_and_write_alternate_ids']['pmc']['completed']).to be true
      expect(tracker['progress']['metadata_ingest']['pubmed']['completed']).to be true
      expect(tracker['progress']['metadata_ingest']['pmc']['completed']).to be true
      expect(tracker['progress']['attach_files_to_works']['completed']).to be true
      expect(tracker['progress']['send_summary_email']['completed']).to be true
    end

    it 'properly coordinates service instantiation and method calls' do
      allow(File).to receive(:exist?).with(/attachment_results\.jsonl/).and_return(true)
      allow(JsonFileUtilsHelper).to receive(:read_jsonl).and_return([])

      service.run

      expect(Tasks::PubmedIngest::Recurring::Utilities::IdRetrievalService).to have_received(:new)
      expect(Tasks::PubmedIngest::Recurring::Utilities::MetadataIngestService).to have_received(:new)
      expect(Tasks::PubmedIngest::Recurring::Utilities::FileAttachmentService).to have_received(:new)

      expect(mock_id_retrieval_service).to have_received(:retrieve_ids_within_date_range).twice
      expect(mock_id_retrieval_service).to have_received(:stream_and_write_alternate_ids).twice
      expect(mock_id_retrieval_service).to have_received(:adjust_id_lists)

      expect(mock_metadata_ingest_service).to have_received(:load_alternate_ids_from_file).twice
      expect(mock_metadata_ingest_service).to have_received(:batch_retrieve_and_process_metadata).twice

      expect(mock_file_attachment_service).to have_received(:run)
    end
  end

  describe 'class methods' do
    let(:now) { Time.utc(2024, 1, 2, 3, 4, 5) }

    before do
      allow(Time).to receive(:now).and_return(now)
      allow(FileUtils).to receive(:mkdir_p)
      allow(Rails).to receive(:root).and_return(Pathname.new('/app'))
      allow(LogUtilsHelper).to receive(:double_log)
    end

    describe '.resolve_output_dir' do
      it 'builds a timestamped path under an absolute base' do
        dir = described_class.send(:resolve_output_dir, '/var/out', now)
        expect(dir.to_s).to match(%r{^/var/out/pubmed_ingest_2024-01-02_03-04-05$})
      end

      it 'builds under Rails.root for a relative base' do
        dir = described_class.send(:resolve_output_dir, 'relative/out', now)
        expect(dir.to_s).to match(%r{^/app/relative/out/pubmed_ingest_2024-01-02_03-04-05$})
      end

      it 'falls back to tmp when blank' do
        dir = described_class.send(:resolve_output_dir, nil, now)
        expect(dir.to_s).to eq('/app/tmp/pubmed_ingest_2024-01-02_03-04-05')
        expect(LogUtilsHelper).to have_received(:double_log).with(
            'No output directory specified. Using default tmp directory.', :info, tag: 'PubMed Ingest'
        )
      end
    end

    describe '.resolve_full_text_dir' do
      let(:output_dir) { Pathname.new('/var/out/pubmed_ingest_2024-01-02_03-04-05') }

      it 'returns provided absolute dir' do
        dir = described_class.send(:resolve_full_text_dir, '/data', output_dir, now)
        expect(dir.to_s).to eq('/data/full_text_pdfs_2024-01-02_03-04-05')
      end

      it 'resolves provided relative dir under Rails.root' do
        dir = described_class.send(:resolve_full_text_dir, 'data', output_dir, now)
        expect(dir.to_s).to eq('/app/data/full_text_pdfs_2024-01-02_03-04-05')
      end
    end

    describe '.write_intro_banner' do
      let(:cfg) do
        {
            'time' => now,
            'output_dir' => '/var/out/x',
            'depositor_onyen' => 'admin',
            'admin_set_title' => 'default',
            'start_date' => Date.parse('2024-01-01'),
            'end_date' => Date.parse('2024-01-31')
        }
      end

      it 'prints banner lines and logs them' do
        allow(Rails.logger).to receive(:info)
        expect {
          described_class.send(:write_intro_banner, config: cfg)
        }.to output(/Start Time: 2024-01-02 03:04:05/).to_stdout

        expect(Rails.logger).to have_received(:info).with(a_string_matching(/PubMed Ingest/)).at_least(:once)
      end
    end

    describe '.build_pubmed_ingest_config_and_tracker' do
      let(:tracker_double) do
      # minimal tracker responding to [] for resume case
        obj = Object.new
        data = { 'full_text_dir' => '/persisted/full_text' }
        obj.define_singleton_method(:[]) { |k| data[k] }
        obj
      end

      context 'new run (resume: false)' do
        let(:args) do
          {
          resume: false,
          output_dir: '/var/out',
          full_text_dir: '/var/full_text',
          start_date: '2024-01-01',
          end_date: '2024-01-31',
          admin_set_title: 'default',
          depositor_onyen: 'someone'
          }
        end

        before do
          admin_set_rel = double('rel', first: double('admin_set'))
          allow(AdminSet).to receive(:where).with(title_tesim: 'default').and_return(admin_set_rel)

          allow(Tasks::PubmedIngest::SharedUtilities::IngestTracker)
          .to receive(:build)
          .and_return(tracker_double)
        end

        it 'returns a config with parsed dates and creates directories' do
          config, tracker = described_class.build_pubmed_ingest_config_and_tracker(args: args)

          expect(config['start_date']).to eq(Date.parse('2024-01-01'))
          expect(config['end_date']).to   eq(Date.parse('2024-01-31'))
          expect(config['depositor_onyen']).to eq('someone')
          expect(config['output_dir']).to match(%r{^/var/out/pubmed_ingest_2024-01-02_03-04-05$})
          expect(config['full_text_dir']).to match(%r{/full_text_pdfs_2024-01-02_03-04-05$})
          expect(tracker).to eq(tracker_double)

            # created base + subdirs + full text
          expect(FileUtils).to have_received(:mkdir_p).with(Pathname.new(config['output_dir']))
          %w[01_build_id_lists 02_load_and_ingest_metadata 03_attach_files_to_works].each do |sub|
            expect(FileUtils).to have_received(:mkdir_p).with(Pathname.new(config['output_dir']).join(sub))
          end
          expect(FileUtils).to have_received(:mkdir_p).with(Pathname.new(config['full_text_dir']))
        end
      end

      context 'resume: true' do
        let(:args) do
          {
          resume: true,
          output_dir: '/var/out/existing',
          depositor_onyen: nil
          }
        end

        it 'loads tracker and carries forward full_text_dir' do
            # Pretend tracker file exists
          allow_any_instance_of(Pathname).to receive(:exist?).and_return(true)

          allow(Tasks::PubmedIngest::SharedUtilities::IngestTracker)
          .to receive(:build)
          .with(config: hash_including('output_dir' => '/var/out/existing', 'restart_time' => now), resume: true)
          .and_return(tracker_double)

          config, tracker = described_class.build_pubmed_ingest_config_and_tracker(args: args)

          expect(config['output_dir']).to eq('/var/out/existing')
          expect(config['full_text_dir']).to eq('/persisted/full_text')
          expect(tracker).to eq(tracker_double)
        end
      end

      context 'validation errors' do
        it 'exits when output_dir is blank' do
          expect {
            described_class.build_pubmed_ingest_config_and_tracker(args: { resume: false, output_dir: nil })
          }.to raise_error(SystemExit)
        end

        it 'exits when required args are missing' do
          expect {
            described_class.build_pubmed_ingest_config_and_tracker(args: {
                resume: false, output_dir: '/var/out',
                start_date: nil, end_date: '2024-01-31', admin_set_title: 'default'
            })
          }.to raise_error(SystemExit)
        end

        it 'exits on invalid date' do
          expect {
            described_class.build_pubmed_ingest_config_and_tracker(args: {
                resume: false, output_dir: '/var/out',
                start_date: 'bogus', end_date: '2024-01-31', admin_set_title: 'default'
            })
          }.to raise_error(SystemExit)
        end

        it 'exits when admin set is not found' do
          allow(AdminSet).to receive(:where).and_return(double('rel', first: nil))
          expect {
            described_class.build_pubmed_ingest_config_and_tracker(args: {
                resume: false, output_dir: '/var/out',
                start_date: '2024-01-01', end_date: '2024-01-31', admin_set_title: 'missing'
            })
          }.to raise_error(SystemExit)
        end

        it 'exits when resume tracker is missing' do
          allow_any_instance_of(Pathname).to receive(:exist?).and_return(false)
          expect {
            described_class.build_pubmed_ingest_config_and_tracker(args: {
                resume: true, output_dir: '/var/out/existing'
            })
          }.to raise_error(SystemExit)
        end
      end
    end
  end
end
