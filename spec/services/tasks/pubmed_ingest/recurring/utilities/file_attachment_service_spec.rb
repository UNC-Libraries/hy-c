# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tasks::PubmedIngest::Recurring::Utilities::FileAttachmentService do
  let(:config) { { test: 'config' } }
  let(:tracker) { double('tracker', save: true) }
  let(:output_path) { '/tmp/test_output' }
  let(:full_text_path) { '/tmp/test_fulltext' }
  let(:metadata_ingest_result_path) { '/tmp/test_metadata.jsonl' }

  let(:service) do
    described_class.new(
      config: config,
      tracker: tracker,
      output_path: output_path,
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
      expect(service.instance_variable_get(:@output_path)).to eq(output_path)
      expect(service.instance_variable_get(:@full_text_path)).to eq(full_text_path)
      expect(service.instance_variable_get(:@metadata_ingest_result_path)).to eq(metadata_ingest_result_path)
    end

    it 'loads existing attachment IDs' do
      expect(service.instance_variable_get(:@existing_ids)).to be_a(Set)
    end
  end

  describe '#load_existing_attachment_ids' do
    context 'when log file does not exist' do
      it 'returns empty set' do
        allow(File).to receive(:exist?).with(/attachment_results\.jsonl/).and_return(false)
        ids = service.load_existing_attachment_ids
        expect(ids).to be_a(Set)
        expect(ids).to be_empty
      end
    end

    context 'when log file exists' do
      let(:log_content) do
        [
          { ids: { pmcid: 'PMC123', pmid: '456' } }.to_json,
          { ids: { pmcid: 'PMC789', pmid: '012' } }.to_json
        ]
      end

      before do
        allow(File).to receive(:exist?).with(/attachment_results\.jsonl/).and_return(true)
        allow(File).to receive(:readlines).and_return(log_content)
      end

      it 'returns set of existing IDs' do
        ids = service.load_existing_attachment_ids
        expect(ids).to include('PMC123', '456', 'PMC789', '012')
      end
    end
  end

  describe '#load_records_to_attach' do
    let(:metadata_content) do
      [
        sample_record.to_json,
        sample_record_without_pmcid.to_json
      ]
    end

    before do
      allow(File).to receive(:foreach).with(metadata_ingest_result_path).and_yield(metadata_content[0]).and_yield(metadata_content[1])
      allow(service).to receive(:filter_record?).and_return(false)
    end

    it 'loads and parses records from metadata file' do
      records = service.load_records_to_attach
      expect(records).to be_an(Array)
      expect(records.size).to eq(2)
    end

    it 'filters records based on filter_record? method' do
      allow(service).to receive(:filter_record?).with(sample_record).and_return(true)
      allow(service).to receive(:filter_record?).with(sample_record_without_pmcid).and_return(false)

      records = service.load_records_to_attach
      expect(records.size).to eq(1)
      expect(records.first).to eq(sample_record_without_pmcid)
    end
  end

  describe '#filter_record?' do
    context 'when record has already been processed' do
      before do
        service.instance_variable_set(:@existing_ids, Set.new(['PMC123456']))
      end

      it 'returns true' do
        expect(service).not_to receive(:log_result).with(
            sample_record,
            category: :successfully_attached,
            message: 'No PMCID found - can only retrieve files with PMCID',
            file_name: 'NONE'
        )

        result = service.filter_record?(sample_record)
        expect(result).to be true
      end
    end

    context 'when record has no PMCID' do
      it 'returns true and logs skip message' do
        expect(service).to receive(:log_result).with(
          sample_record_without_pmcid,
          category: :successfully_attached,
          message: 'No PMCID found - can only retrieve files with PMCID',
          file_name: 'NONE'
        )

        result = service.filter_record?(sample_record_without_pmcid)
        expect(result).to be true
      end
    end

    context 'when work already has files attached' do
      before do
        allow(service).to receive(:has_fileset?).with('work_123').and_return(true)
      end

      it 'returns true and logs skip message' do
        expect(service).to receive(:log_result).with(
          sample_record,
          category: :skipped,
          message: 'Work already has files attached',
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

  describe '#has_fileset?' do
    context 'when work has file sets' do
      before do
        allow(WorkUtilsHelper).to receive(:fetch_work_data_by_id).with('work_123').and_return({
          file_set_ids: ['file1', 'file2']
        })
      end

      it 'returns true' do
        result = service.has_fileset?('work_123')
        expect(result).to be true
      end
    end

    context 'when work has no file sets' do
      before do
        allow(WorkUtilsHelper).to receive(:fetch_work_data_by_id).with('work_123').and_return({
          file_set_ids: []
        })
      end

      it 'returns false' do
        result = service.has_fileset?('work_123')
        expect(result).to be false
      end
    end

    context 'when work does not exist' do
      before do
        allow(WorkUtilsHelper).to receive(:fetch_work_data_by_id).with('work_123').and_return(nil)
      end

      it 'returns false' do
        result = service.has_fileset?('work_123')
        expect(result).to be false
      end
    end
  end

  describe '#process_record' do
    let(:oa_response_body) do
      <<~XML
        <?xml version="1.0"?>
        <oa>
          <record>
            <link format="pdf" href="ftp://example.com/path/file.pdf"/>
          </record>
        </oa>
      XML
    end

    let(:mock_response) { double('response', code: 200, body: oa_response_body) }

    before do
      allow(HTTParty).to receive(:get).and_return(mock_response)
      allow(service).to receive(:fetch_ftp_binary).and_return('pdf_binary_data')
      allow(service).to receive(:attach_pdf_to_work_with_binary!)
      allow(service).to receive(:sleep)
    end

    context 'when record has no PMCID' do
      it 'returns early' do
        expect(HTTParty).not_to receive(:get)
        service.process_record(sample_record_without_pmcid)
      end
    end

    context 'when PDF URL is found' do
      before do
        stub_const('Tasks::PubmedIngest::Recurring::Utilities::FileAttachmentService::RETRY_LIMIT', 0)
        allow(service).to receive(:generate_filename_for_work).and_return('PMC123456_001.pdf')
        allow(service).to receive(:attach_pdf_to_work_with_binary!).and_return([double('fileset'), 'PMC123456_001.pdf'])
      end
      it 'fetches and processes PDF' do
        service.process_record(sample_record)

        expect(HTTParty).to have_received(:get).with(
          'https://www.ncbi.nlm.nih.gov/pmc/utils/oa/oa.fcgi?id=PMC123456',
          timeout: 10
        )
        expect(service).to have_received(:fetch_ftp_binary)
        expect(service).to have_received(:attach_pdf_to_work_with_binary!)
      end
    end

    context 'when TGZ URL is found' do
      let(:oa_response_body) do
        <<~XML
          <?xml version="1.0"?>
          <oa>
            <record>
              <link format="tgz" href="ftp://example.com/path/file.tgz"/>
            </record>
          </oa>
        XML
      end

      before do
        allow(service).to receive(:process_and_attach_tgz_file)
      end

      it 'fetches and processes TGZ' do
        service.process_record(sample_record)

        expect(service).to have_received(:fetch_ftp_binary)
        expect(service).to have_received(:process_and_attach_tgz_file)
      end
    end

    context 'when no PDF or TGZ link is found' do
      let(:oa_response_body) do
        <<~XML
          <?xml version="1.0"?>
          <oa>
            <record>
            </record>
          </oa>
        XML
      end

      it 'logs successful ingestion with no attachment' do
        expect(service).to receive(:log_result).with(
          sample_record,
          category: :successfully_attached,
          message: 'No PDF or TGZ link found, skipping attachment',
          file_name: 'NONE'
        )

        service.process_record(sample_record)
      end
    end

    context 'when API request fails' do
      let(:mock_response) { double('response', code: 500, body: '') }

      it 'retries and eventually logs failure' do
        expect(service).to receive(:log_result).with(
          sample_record,
          category: :failed,
          message: /File attachment failed -- Bad response: 500/,
          file_name: 'NONE'
        )

        service.process_record(sample_record)
      end
    end
  end

  describe '#fetch_ftp_binary' do
    let(:uri) { URI.parse('ftp://example.com/path/file.pdf') }
    let(:mock_ftp) { double('ftp') }
    let(:binary_data) { 'binary_file_content' }

    before do
      allow(Net::FTP).to receive(:open).with('example.com').and_yield(mock_ftp)
      allow(mock_ftp).to receive(:login)
      allow(mock_ftp).to receive(:passive=)
      allow(mock_ftp).to receive(:getbinaryfile).and_yield(binary_data)
    end

    it 'connects to FTP and downloads binary data' do
      result = service.fetch_ftp_binary(uri)

      expect(Net::FTP).to have_received(:open).with('example.com')
      expect(mock_ftp).to have_received(:login)
      expect(mock_ftp).to have_received(:passive=).with(true)
      expect(mock_ftp).to have_received(:getbinaryfile).with('/path/file.pdf', nil)
      expect(result).to eq(binary_data)
    end
  end

  describe '#safe_gzip_reader' do
    before do
      allow(File).to receive(:open).and_call_original
    end

    let(:temp_file) { Tempfile.new('test_gzip') }
    let(:gzipped_content) do
      # Create actual gzipped content
      string_io = StringIO.new
      gzip_writer = Zlib::GzipWriter.new(string_io)
      gzip_writer.write('test content')
      gzip_writer.close
      string_io.string
    end

    before do
      temp_file.binmode
      temp_file.write('prefix_data')
      temp_file.write(gzipped_content)
      temp_file.close
    end

    after do
      temp_file.unlink
    end

    it 'finds gzip header and creates reader' do
      reader = service.safe_gzip_reader(temp_file.path)
      expect(reader).to be_a(Zlib::GzipReader)
      content = reader.read
      expect(content).to eq('test content')
      reader.close
    end

    context 'when no gzip header is found' do
      let(:temp_file_no_gzip) { Tempfile.new('no_gzip') }

      before do
        temp_file_no_gzip.write('no gzip header here')
        temp_file_no_gzip.close
      end

      after do
        temp_file_no_gzip.unlink
      end

      it 'raises an error' do
        expect {
          service.safe_gzip_reader(temp_file_no_gzip.path)
        }.to raise_error('No GZIP header found in file')
      end
    end
  end

  describe '#process_and_attach_tgz_file' do
    let(:tgz_path) { '/full/path/PMC123456.tar.gz' }
    let(:mock_article) { double('article', id: 'work_123', reload: true, update_index: true) }
    let(:mock_user) { double('user', uid: 'admin') }
    let(:mock_gz_reader) { double('gz_reader', close: true) }
    let(:mock_tar_reader) { double('tar_reader') }
    let(:mock_pdf_entry) { double('entry', file?: true, full_name: 'article.pdf', read: 'pdf_binary') }

    before do
      allow(Article).to receive(:find).with('work_123').and_return(mock_article)
      allow(User).to receive(:find_by).with(uid: 'admin').and_return(mock_user)
      allow(File).to receive(:expand_path).with(tgz_path).and_return(tgz_path)
      allow(service).to receive(:safe_gzip_reader).and_return(mock_gz_reader)
      allow(Gem::Package::TarReader).to receive(:new).with(mock_gz_reader).and_yield(mock_tar_reader)
      allow(service).to receive(:generate_filename_for_work).and_return('PMC123456_001.pdf')
      allow(service).to receive(:attach_pdf_to_work_with_binary!).and_return([double('fileset'), 'PMC123456_001.pdf'])
      allow(File).to receive(:exist?).with(tgz_path).and_return(true)
      allow(File).to receive(:delete).with(tgz_path)
    end

    context 'when work ID is present' do
      before do
        allow(mock_tar_reader).to receive(:each).and_yield(mock_pdf_entry)
      end

      it 'processes TGZ file and attaches PDFs' do
        expect(service).to receive(:log_result).with(
          sample_record,
          category: :successfully_attached,
          message: 'PDF successfully attached from TGZ.',
          file_name: 'PMC123456_001.pdf'
        )

        service.process_and_attach_tgz_file(sample_record, tgz_path)

        expect(mock_article).to have_received(:reload)
        expect(mock_article).to have_received(:update_index)
        expect(File).to have_received(:delete).with(tgz_path)
      end
    end

    context 'when TGZ contains a nested PDF file' do
      let(:nested_pdf_entry) { double('entry', file?: true, full_name: 'nested/article.pdf', read: 'pdf_binary') }

      before do
        allow(mock_tar_reader).to receive(:each).and_yield(nested_pdf_entry)
      end

      it 'still attaches the PDF' do
        expect(service).to receive(:log_result).with(
          sample_record,
          category: :successfully_attached,
          message: 'PDF successfully attached from TGZ.',
          file_name: 'PMC123456_001.pdf'
        )

        service.process_and_attach_tgz_file(sample_record, tgz_path)
      end
    end

    context 'when work ID is blank' do
      let(:record_without_work_id) do
        { 'ids' => { 'pmcid' => 'PMC123456' } }
      end

      it 'logs skip message and returns early' do
        expect(service).to receive(:log_result).with(
          record_without_work_id,
          category: :skipped,
          message: 'No article ID found to attach TGZ',
          file_name: 'NONE'
        )

        service.process_and_attach_tgz_file(record_without_work_id, tgz_path)
      end
    end

    context 'when no PDF files found in TGZ' do
      let(:mock_non_pdf_entry) { double('entry', file?: true, full_name: 'data.xml', read: 'xml_content') }

      before do
        allow(mock_tar_reader).to receive(:each).and_yield(mock_non_pdf_entry)
      end

      it 'logs failure message' do
        expect(service).to receive(:log_result).with(
          sample_record,
          category: :failed,
          message: /No PDF files found in TGZ archive/,
          file_name: 'NONE'
        )

        service.process_and_attach_tgz_file(sample_record, tgz_path)
      end
    end

    context 'when processing fails' do
      before do
        allow(Article).to receive(:find).and_raise(StandardError.new('Article not found'))
      end

      it 'logs failure and error details' do
        expect(service).to receive(:log_result).with(
          sample_record,
          category: :failed,
          message: /TGZ PDF processing failed: Article not found/,
          file_name: 'NONE'
        )

        service.process_and_attach_tgz_file(sample_record, tgz_path)
      end
    end
  end


  describe '#generate_filename_for_work' do
    context 'when work exists and has file sets' do
      before do
        allow(WorkUtilsHelper).to receive(:fetch_work_data_by_id).with('work_123').and_return({
          file_set_ids: ['file1', 'file2']
        })
      end

      it 'generates filename with incremented suffix' do
        filename = service.generate_filename_for_work('work_123', 'PMC123456')
        expect(filename).to eq('PMC123456_003.pdf')
      end
    end

    context 'when work exists but has no file sets' do
      before do
        allow(WorkUtilsHelper).to receive(:fetch_work_data_by_id).with('work_123').and_return({
          file_set_ids: []
        })
      end

      it 'generates filename with 001 suffix' do
        filename = service.generate_filename_for_work('work_123', 'PMC123456')
        expect(filename).to eq('PMC123456_001.pdf')
      end
    end

    context 'when work does not exist' do
      before do
        allow(WorkUtilsHelper).to receive(:fetch_work_data_by_id).with('work_123').and_return(nil)
      end

      it 'returns nil' do
        filename = service.generate_filename_for_work('work_123', 'PMC123456')
        expect(filename).to be_nil
      end
    end
  end

  describe '#log_result' do
    let(:log_file_handle) { double('file') }

    before do
      allow(Time).to receive(:now).and_return(Time.parse('2024-01-01 12:00:00 UTC'))
      allow(File).to receive(:open).with(/attachment_results\.jsonl/, 'a').and_yield(log_file_handle)
      allow(log_file_handle).to receive(:puts)
    end

    it 'writes log entry to file and saves tracker' do
      service.log_result(
        sample_record,
        category: :successfully_attached,
        message: 'File attached successfully',
        file_name: 'PMC123456_001.pdf'
      )

      expected_entry = {
        ids: sample_record['ids'],
        timestamp: '2024-01-01T12:00:00Z',
        category: :successfully_attached,
        message: 'File attached successfully',
        file_name: 'PMC123456_001.pdf'
      }

      expect(log_file_handle).to have_received(:puts).with(expected_entry.to_json)
      expect(tracker).to have_received(:save)
    end
  end

  describe '#run' do
    let(:records) { [sample_record, sample_record_without_pmcid] }

    before do
      service.instance_variable_set(:@records, records)
      allow(service).to receive(:process_record)
    end

    it 'processes all records' do
      service.run

      expect(service).to have_received(:process_record).with(sample_record)
      expect(service).to have_received(:process_record).with(sample_record_without_pmcid)
      expect(LogUtilsHelper).to have_received(:double_log).with(
        'Processing record 1 of 2', :info, tag: 'Attachment'
      )
      expect(LogUtilsHelper).to have_received(:double_log).with(
        'Processing record 2 of 2', :info, tag: 'Attachment'
      )
    end
  end
end
