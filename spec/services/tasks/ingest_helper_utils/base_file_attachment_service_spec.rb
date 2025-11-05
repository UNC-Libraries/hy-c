# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::IngestHelperUtils::BaseFileAttachmentService, type: :service do
  let(:config) { { 'admin_set_title' => 'Test Admin Set', 'depositor_onyen' => 'admin' } }
  let(:tracker) { double('Tracker', save: true) }
  let(:log_file_path) { '/tmp/test_log.jsonl' }
  let(:metadata_path) { '/tmp/test_metadata.jsonl' }
  let(:admin_set) { instance_double('AdminSet') }

  subject(:service) do
    described_class.new(
      config: config,
      tracker: tracker,
      log_file_path: log_file_path,
      metadata_ingest_result_path: metadata_path
    )
  end

  before do
    allow(AdminSet).to receive(:where).with(title: 'Test Admin Set').and_return([admin_set])
    allow(LogUtilsHelper).to receive(:double_log)
    allow(File).to receive(:open).and_yield(StringIO.new)
  end

  describe '#initialize' do
    it 'sets up instance variables correctly' do
      expect(service.config).to eq(config)
      expect(service.tracker).to eq(tracker)
      expect(service.log_file_path).to eq(log_file_path)
      expect(service.instance_variable_get(:@metadata_ingest_result_path)).to eq(metadata_path)
      expect(service.admin_set).to eq(admin_set)
      expect(service.write_buffer).to eq([])
    end
  end

  describe '#process_record' do
    it 'raises NotImplementedError' do
      expect { service.process_record({}) }.to raise_error(NotImplementedError)
    end
  end

  describe '#filter_record?' do
    before { service.instance_variable_set(:@existing_ids, ['already_seen']) }

    it 'skips when work_id already seen' do
      record = { 'ids' => { 'work_id' => 'already_seen' } }
      expect(service.filter_record?(record)).to be true
    end

    it 'skips non-UNC affiliation category' do
      record = { 'category' => 'skipped_non_unc_affiliation', 'ids' => {} }
      expect(service).to receive(:log_attachment_outcome)
      expect(service.filter_record?(record)).to be true
    end

    it 'skips failed category' do
      record = { 'category' => 'failed', 'ids' => {} }
      expect(service).to receive(:log_attachment_outcome)
      expect(service.filter_record?(record)).to be true
    end

    it 'skips works that already have files' do
      allow(WorkUtilsHelper).to receive(:fetch_work_data_by_id)
        .with('work_with_files')
        .and_return({ file_set_ids: ['abc'] })

      record = { 'ids' => { 'work_id' => 'work_with_files' }, 'category' => 'anything' }
      expect(service).to receive(:log_attachment_outcome)
      expect(service.filter_record?(record)).to be true
    end

    it 'returns false for records that should be processed' do
      allow(WorkUtilsHelper).to receive(:fetch_work_data_by_id).and_return({ file_set_ids: [] })
      record = { 'ids' => { 'work_id' => 'new_work' }, 'category' => 'successfully_ingested' }
      expect(service.filter_record?(record)).to be false
    end
  end

  describe '#fetch_attachment_candidates' do
    let(:record_json) { { 'ids' => { 'work_id' => '123' } }.to_json }

    it 'returns empty array if metadata file does not exist' do
      allow(File).to receive(:exist?).with(metadata_path).and_return(false)
      expect(service.fetch_attachment_candidates).to eq([])
    end

    it 'loads and filters records from JSONL file' do
      allow(File).to receive(:exist?).with(metadata_path).and_return(true)
      allow(File).to receive(:foreach).with(metadata_path).and_yield(record_json)
      allow(service).to receive(:filter_record?).and_return(false)

      results = service.fetch_attachment_candidates
      expect(results).to be_an(Array)
      expect(results.first['ids']['work_id']).to eq('123')
    end
  end

  describe '#load_seen_attachment_ids' do
    it 'returns empty set when file does not exist' do
      allow(File).to receive(:exist?).with(log_file_path).and_return(false)
      expect(service.load_seen_attachment_ids).to eq(Set.new)
    end

    it 'loads IDs from JSON lines when file exists' do
      json_line = { 'ids' => { 'pmid' => '12345', 'pmcid' => '54321' } }.to_json
      allow(File).to receive(:exist?).with(log_file_path).and_return(true)
      allow(File).to receive(:readlines).with(log_file_path).and_return([json_line])

      ids = service.load_seen_attachment_ids
      expect(ids).to include('12345', '54321')
    end
  end

  describe '#has_fileset?' do
    it 'returns true when work has file_set_ids' do
      allow(WorkUtilsHelper).to receive(:fetch_work_data_by_id).and_return({ file_set_ids: ['abc'] })
      expect(service.has_fileset?('work123')).to be true
    end

    it 'returns false when no filesets' do
      allow(WorkUtilsHelper).to receive(:fetch_work_data_by_id).and_return({ file_set_ids: [] })
      expect(service.has_fileset?('work123')).to be false
    end
  end

  describe '#generate_filename_for_work' do
    it 'returns incremented filename when filesets exist' do
      allow(WorkUtilsHelper).to receive(:fetch_work_data_by_id)
        .and_return({ file_set_ids: ['f1', 'f2'], work_id: 'work1' })
      result = service.generate_filename_for_work('work1', 'PMC123')
      expect(result).to eq('PMC123_003.pdf')
    end

    it 'returns first filename when no filesets' do
      allow(WorkUtilsHelper).to receive(:fetch_work_data_by_id)
        .and_return({ file_set_ids: [], work_id: 'work1' })
      result = service.generate_filename_for_work('work1', 'PMC123')
      expect(result).to eq('PMC123_001.pdf')
    end

    context 'when work exists but has no file sets' do
      before do
        allow(WorkUtilsHelper).to receive(:fetch_work_data_by_id).with('work_123').and_return({
          file_set_ids: [],
          work_id: 'work_123'
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

  describe '#log_attachment_outcome' do
    let(:record) { { 'ids' => { 'pmid' => '12345' } } }

    it 'writes JSON log entry to file' do
      io = StringIO.new
      allow(File).to receive(:open).with(log_file_path, 'a').and_yield(io)

      service.log_attachment_outcome(record, category: :success, message: 'ok', file_name: 'test.pdf')

      io.rewind
      json = JSON.parse(io.string)
      expect(json['category']).to eq('success')
      expect(json['file_name']).to eq('test.pdf')
    end
  end

  describe '#category_for_skipped_file_attachment' do
    it 'returns :skipped_file_attachment for skipped record' do
      record = { 'category' => 'skipped' }
      expect(service.category_for_skipped_file_attachment(record)).to eq(:skipped_file_attachment)
    end

    it 'returns :successfully_ingested_metadata_only otherwise' do
      record = { 'category' => 'new' }
      expect(service.category_for_skipped_file_attachment(record)).to eq(:successfully_ingested_metadata_only)
    end
  end

  describe '#category_for_successful_attachment' do
    it 'returns :successfully_attached for skipped records' do
      record = { 'category' => 'skipped' }
      expect(service.category_for_successful_attachment(record)).to eq(:successfully_attached)
    end

    it 'returns :successfully_ingested_and_attached otherwise' do
      record = { 'category' => 'fresh' }
      expect(service.category_for_successful_attachment(record)).to eq(:successfully_ingested_and_attached)
    end
  end


  describe '#run' do
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
    let(:records) { [sample_record, sample_record_without_pmcid] }

    before do
      service.instance_variable_set(:@records, records)
      allow(service).to receive(:process_record)
      allow(service).to receive(:sync_permissions_and_state!)
      allow(service).to receive(:fetch_attachment_candidates).and_return(records)
      allow(Rails.logger).to receive(:info)
    end

    it 'processes all records' do
      service.run

      expect(service).to have_received(:process_record).with(sample_record)
      expect(service).to have_received(:process_record).with(sample_record_without_pmcid)
      expect(service).to have_received(:sync_permissions_and_state!).with(work_id: 'work_123', depositor_uid: 'admin', admin_set: admin_set)
      expect(Rails.logger).to have_received(:info).with('Processing record 1 of 2')
      expect(Rails.logger).to have_received(:info).with('Processing record 2 of 2')
    end
  end
end
