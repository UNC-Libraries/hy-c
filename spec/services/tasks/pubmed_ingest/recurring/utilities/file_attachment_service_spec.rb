# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::PubmedIngest::Recurring::Utilities::FileAttachmentService do
  let(:config) { { 'depositor_onyen' => 'admin' } }
  let(:tracker) { double('tracker', save: true) }
  let(:log_file_path) { '/tmp/test_output' }
  let(:full_text_path) { '/tmp/test_fulltext' }
  let(:metadata_ingest_result_path) { '/tmp/test_metadata.jsonl' }

  let(:service) do
    described_class.new(
      config: config,
      tracker: tracker,
      log_file_path: log_file_path,
      full_text_path: full_text_path,
      metadata_ingest_result_path: metadata_ingest_result_path
    )
  end

  let(:sample_record) do
    {
      'ids' => {
        'pmcid' => 'PMC123456',
        'pmid' => '987654',
        'work_id' => 'work_123'
      },
      'title' => 'Sample Article'
    }
  end

  let(:sample_record_without_pmcid) do
    {
      'ids' => {
        'pmid' => '987654',
        'work_id' => 'work_123'
      },
      'title' => 'Sample Article Without PMCID'
    }
  end

  before do
    allow(LogUtilsHelper).to receive(:double_log)
    allow(FileUtils).to receive(:mkdir_p)
    allow(Dir).to receive(:exist?).and_return(false)
    allow(File).to receive(:exist?).and_return(false)
    allow(File).to receive(:join).and_call_original
    allow(File).to receive(:foreach)
    allow(File).to receive(:readlines).and_return([])
    allow(File).to receive(:open)
    allow(WorkUtilsHelper).to receive(:fetch_work_data_by_id)
    allow(Rails.logger).to receive(:error)
  end

  describe '#initialize' do
    it 'sets up instance variables correctly' do
      expect(service.instance_variable_get(:@config)).to eq(config)
      expect(service.instance_variable_get(:@tracker)).to eq(tracker)
      expect(service.instance_variable_get(:@log_file_path)).to eq(log_file_path)
      expect(service.instance_variable_get(:@full_text_path)).to eq(full_text_path)
      expect(service.instance_variable_get(:@metadata_ingest_result_path)).to eq(metadata_ingest_result_path)
    end

    it 'loads existing attachment IDs' do
      expect(service.instance_variable_get(:@existing_ids)).to be_a(Set)
    end
  end

  describe '#filter_record?' do
    context 'when record has already been processed' do
      before do
        service.instance_variable_set(:@existing_ids, Set.new(['PMC123456']))
      end

      it 'returns true' do
        expect(service).not_to receive(:log_attachment_outcome).with(
            sample_record,
            category: :successfully_ingested_metadata_only,
            message: 'No PMCID found - can only retrieve files with PMCID',
            file_name: 'NONE'
        )

        result = service.filter_record?(sample_record)
        expect(result).to be true
      end
    end

    context 'when record has no PMCID' do
      it 'logs as successfully_ingested_metadata_only by default' do
        expect(service).to receive(:log_attachment_outcome).with(
          sample_record_without_pmcid,
          category: :successfully_ingested_metadata_only,
          message: 'No PMCID found - can only retrieve files with PMCID',
          file_name: 'NONE'
        )

        result = service.filter_record?(sample_record_without_pmcid)
        expect(result).to be true
      end

      it 'logs as skipped_file_attachment if record category is skipped' do
        record = sample_record_without_pmcid.merge('category' => 'skipped')
        expect(service).to receive(:log_attachment_outcome).with(
          record,
          category: :skipped_file_attachment,
          message: 'No PMCID found - can only retrieve files with PMCID',
          file_name: 'NONE'
        )

        result = service.filter_record?(record)
        expect(result).to be true
      end

      it 'logs as skipped_non_unc_affiliation if record category is skipped_non_unc_affiliation' do
        record = sample_record_without_pmcid.merge('category' => 'skipped_non_unc_affiliation')
        expect(service).to receive(:log_attachment_outcome).with(
          record,
          category: :skipped_non_unc_affiliation,
          message: 'N/A',
          file_name: 'NONE'
        )

        result = service.filter_record?(record)
        expect(result).to be true
      end
    end

    context 'when work already has files attached' do
      before do
        allow(service).to receive(:has_fileset?).with('work_123').and_return(true)
      end

      it 'returns true and logs skip message' do
        expect(service).to receive(:log_attachment_outcome).with(
          sample_record,
          category: :skipped,
          message: 'Already exists and has files attached',
          file_name: 'NONE'
        )

        result = service.filter_record?(sample_record)
        expect(result).to be true
      end
    end

    context 'when record should be processed' do
      before do
        allow(service).to receive(:has_fileset?).with('work_123').and_return(false)
      end

      it 'returns false' do
        result = service.filter_record?(sample_record)
        expect(result).to be false
      end
    end
  end

  describe '#process_record' do
    let(:mock_s3_client) { double('s3_client') }
    let(:mock_list_response) do
      double('list_response', common_prefixes: [double('prefix', prefix: 'PMC123456.1/')])
    end

    before do
      allow(service).to receive(:s3_client).and_return(mock_s3_client)
      allow(mock_s3_client).to receive(:list_objects_v2).and_return(mock_list_response)
      allow(mock_s3_client).to receive(:get_object)
      allow(service).to receive(:attach_pdf_to_work_with_file_path!)
      allow(service).to receive(:generate_filename_for_work).and_return('PMC123456_001.pdf')
      allow(service).to receive(:sleep)
    end

    context 'when record has no PMCID' do
      it 'returns early without calling S3' do
        expect(mock_s3_client).not_to receive(:list_objects_v2)
        service.process_record(sample_record_without_pmcid)
      end
    end

    context 'when PDF is found in S3' do
      before do
        allow(service).to receive(:attach_pdf_to_work_with_file_path!)
          .and_return([double('fileset'), 'PMC123456_001.pdf'])
        allow(service).to receive(:log_attachment_outcome)
      end

      it 'lists S3 versions, downloads the PDF, and attaches it' do
        service.process_record(sample_record)

        expect(mock_s3_client).to have_received(:list_objects_v2).with(
          bucket: Tasks::PubmedIngest::Recurring::Utilities::FileAttachmentService::PMC_S3_BUCKET,
          prefix: 'PMC123456.',
          delimiter: '/'
        )
        expect(mock_s3_client).to have_received(:get_object).with(
          bucket: Tasks::PubmedIngest::Recurring::Utilities::FileAttachmentService::PMC_S3_BUCKET,
          key: 'PMC123456.1/PMC123456.1.pdf',
          response_target: anything
        )
        expect(service).to have_received(:attach_pdf_to_work_with_file_path!)
      end

      it 'logs as successfully_ingested_and_attached by default' do
        service.process_record(sample_record)

        expect(service).to have_received(:log_attachment_outcome).with(
          sample_record,
          category: :successfully_ingested_and_attached,
          message: 'PDF successfully attached.',
          file_name: 'PMC123456_001.pdf'
        )
      end

      it 'logs as successfully_attached if record.category is skipped' do
        sample_record['category'] = 'skipped'
        service.process_record(sample_record)

        expect(service).to have_received(:log_attachment_outcome).with(
          sample_record,
          category: :successfully_attached,
          message: 'PDF successfully attached.',
          file_name: 'PMC123456_001.pdf'
        )
      end
    end

    context 'when no PDF is found in S3' do
      before do
        allow(mock_s3_client).to receive(:get_object)
          .and_raise(Aws::S3::Errors::NoSuchKey.new(nil, 'The specified key does not exist.'))
        allow(service).to receive(:log_attachment_outcome)
      end

      it 'logs successfully_ingested_metadata_only by default' do
        service.process_record(sample_record)

        expect(service).to have_received(:log_attachment_outcome).with(
          sample_record,
          category: :successfully_ingested_metadata_only,
          message: 'No PDF found in S3 for PMCID',
          file_name: 'NONE'
        )
      end

      it 'logs skipped_file_attachment if record.category is skipped' do
        sample_record['category'] = 'skipped'
        service.process_record(sample_record)

        expect(service).to have_received(:log_attachment_outcome).with(
          sample_record,
          category: :skipped_file_attachment,
          message: 'No PDF found in S3 for PMCID',
          file_name: 'NONE'
        )
      end
    end

    context 'when no versions are found in S3' do
      let(:empty_list_response) { double('empty_response', common_prefixes: []) }

      before do
        allow(mock_s3_client).to receive(:list_objects_v2).and_return(empty_list_response)
        allow(service).to receive(:log_attachment_outcome)
      end

      it 'logs successfully_ingested_metadata_only by default' do
        service.process_record(sample_record)

        expect(service).to have_received(:log_attachment_outcome).with(
          sample_record,
          category: :successfully_ingested_metadata_only,
          message: 'No versions found in S3 for PMCID',
          file_name: 'NONE'
        )
      end
    end

    context 'when S3 request fails with a retryable error' do
      before do
        stub_const('Tasks::PubmedIngest::Recurring::Utilities::FileAttachmentService::RETRY_LIMIT', 0)
        allow(mock_s3_client).to receive(:list_objects_v2)
          .and_raise(StandardError.new('Service unavailable'))
        allow(service).to receive(:log_attachment_outcome)
      end

      it 'retries and eventually logs failure' do
        service.process_record(sample_record)

        expect(service).to have_received(:log_attachment_outcome).with(
          sample_record,
          category: :failed,
          message: 'File attachment failed -- Service unavailable',
          file_name: 'NONE'
        )
      end
    end
  end
end
