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
    before do
      allow(service).to receive(:latest_version_prefix).and_return('PMC123456.1/')
      allow(service).to receive(:fetch_s3_file).and_return(200)
      allow(service).to receive(:generate_filename_for_work).and_return('PMC123456_001.pdf')
      allow(service).to receive(:attach_pdf_to_work_with_file_path!)
        .and_return([double('fileset'), 'PMC123456_001.pdf'])
      allow(service).to receive(:log_attachment_outcome)
      allow(service).to receive(:sleep)
    end

    context 'when record has no PMCID' do
      it 'returns early without fetching from S3' do
        expect(service).not_to receive(:latest_version_prefix)
        service.process_record(sample_record_without_pmcid)
      end
    end

    context 'when PDF is found in S3' do
      it 'fetches the latest version, downloads the PDF, and attaches it' do
        service.process_record(sample_record)

        expect(service).to have_received(:latest_version_prefix).with('PMC123456')
        expect(service).to have_received(:fetch_s3_file).with(
          'https://pmc-oa-opendata.s3.amazonaws.com/PMC123456.1/PMC123456.1.pdf',
          local_file_path: anything
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

    context 'when no PDF is found in S3 (404)' do
      before { allow(service).to receive(:fetch_s3_file).and_return(404) }

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
      before { allow(service).to receive(:latest_version_prefix).and_return(nil) }

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

    context 'when a retryable error occurs' do
      before do
        stub_const('Tasks::PubmedIngest::Recurring::Utilities::FileAttachmentService::RETRY_LIMIT', 0)
        allow(service).to receive(:latest_version_prefix).and_raise(StandardError.new('Service unavailable'))
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

  describe '#latest_version_prefix' do
    let(:list_xml) do
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
          <CommonPrefixes><Prefix>PMC123456.1/</Prefix></CommonPrefixes>
          <CommonPrefixes><Prefix>PMC123456.2/</Prefix></CommonPrefixes>
        </ListBucketResult>
      XML
    end

    before do
      allow(HTTParty).to receive(:get)
        .with(a_string_including('PMC123456.'), anything)
        .and_return(double('response', code: 200, body: list_xml))
    end

    it 'returns the latest (sorted) version prefix' do
      expect(service.latest_version_prefix('PMC123456')).to eq('PMC123456.2/')
    end

    context 'when no versions exist' do
      let(:empty_xml) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
          </ListBucketResult>
        XML
      end

      before do
        allow(HTTParty).to receive(:get)
          .and_return(double('response', code: 200, body: empty_xml))
      end

      it 'returns nil' do
        expect(service.latest_version_prefix('PMC123456')).to be_nil
      end
    end

    context 'when the S3 listing request fails' do
      before do
        allow(HTTParty).to receive(:get)
          .and_return(double('response', code: 500, body: ''))
      end

      it 'raises an error' do
        expect { service.latest_version_prefix('PMC123456') }.to raise_error(/S3 listing failed/)
      end
    end
  end

  describe '#fetch_s3_file' do
    let(:url) { 'https://pmc-oa-opendata.s3.amazonaws.com/PMC123456.1/PMC123456.1.pdf' }
    let(:local_path) { '/tmp/test_fulltext/PMC123456_001.pdf' }

    before { allow(File).to receive(:binwrite) }

    it 'writes the body to disk and returns 200 on success' do
      allow(HTTParty).to receive(:get).and_return(double('response', code: 200, body: 'pdf_content'))

      result = service.fetch_s3_file(url, local_file_path: local_path)

      expect(result).to eq(200)
      expect(File).to have_received(:binwrite).with(local_path, 'pdf_content')
    end

    it 'returns 404 without writing a file when not found' do
      allow(HTTParty).to receive(:get).and_return(double('response', code: 404, body: ''))

      result = service.fetch_s3_file(url, local_file_path: local_path)

      expect(result).to eq(404)
      expect(File).not_to have_received(:binwrite)
    end
  end
end
