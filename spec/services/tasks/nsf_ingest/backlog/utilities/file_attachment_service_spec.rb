# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::NsfIngest::Backlog::Utilities::FileAttachmentService, type: :service do
  let(:config) do
    {
      'depositor_onyen' => 'test-user',
      'file_info_csv_path' => '/tmp/file_info.csv',
      'full_text_dir' => '/tmp/full_text_pdfs'
    }
  end

  let(:tracker) { double('Tracker', save: true) }
  let(:log_file_path) { '/tmp/log.jsonl' }
  let(:file_info_path) { '/tmp/file_info.csv' }
  let(:metadata_ingest_result_path) { '/tmp/metadata_results.jsonl' }

  before do
    # ✅ Stub BEFORE subject is created
    allow(CSV).to receive(:foreach).and_yield(CSV::Row.new(%w[doi filename], ['10.1000/test', 'file1.pdf']))
                                 .and_yield(CSV::Row.new(%w[doi filename], ['10.1000/test', 'file2.pdf']))
                                 .and_yield(CSV::Row.new(%w[doi filename], ['10.1001/alt', 'other.pdf']))

    allow_any_instance_of(Tasks::IngestHelperUtils::BaseFileAttachmentService)
      .to receive(:load_seen_attachment_ids).and_return(Set.new)
    allow_any_instance_of(Tasks::IngestHelperUtils::BaseFileAttachmentService)
      .to receive(:fetch_attachment_candidates)
      .and_return([{ 'ids' => { 'work_id' => 'abc123', 'doi' => '10.1000/test' } }])
    allow(File).to receive(:join).and_call_original
    allow(Rails.logger).to receive(:error)
  end

  subject(:service) do
    described_class.new(
      config: config,
      tracker: tracker,
      log_file_path: log_file_path,
      file_info_path: file_info_path,
      metadata_ingest_result_path: metadata_ingest_result_path
    )
  end

  describe '#initialize' do
    it 'sets expected instance variables' do
      expect(service.instance_variable_get(:@file_info_path)).to eq(file_info_path)
      expect(service.instance_variable_get(:@metadata_ingest_result_path)).to eq(metadata_ingest_result_path)
      expect(service.instance_variable_get(:@existing_ids)).to be_a(Set)
      expect(service.instance_variable_get(:@records)).to be_an(Array)
      expect(service.instance_variable_get(:@doi_to_filenames)).to be_a(Hash)
      expect(service.instance_variable_get(:@full_text_path)).to eq('/tmp/full_text_pdfs')
    end
  end

  describe '#generate_doi_to_filenames' do
    it 'returns a hash mapping DOIs to arrays of filenames' do
      result = service.generate_doi_to_filenames
      expect(result).to eq({
        '10.1000/test' => ['file1.pdf', 'file2.pdf'],
        '10.1001/alt' => ['other.pdf']
      })
    end
  end

  describe '#process_record' do
    let(:record) do
      { 'ids' => { 'work_id' => 'abc123', 'doi' => '10.1000/test' } }
    end

    before do
      service.instance_variable_set(:@full_text_path, '/tmp/full_text_pdfs')
      service.instance_variable_set(:@doi_to_filenames, { '10.1000/test' => ['paper.pdf'] })
      allow(service).to receive(:attach_pdf_to_work_with_file_path!)
        .and_return(double('FileSet'))
      allow(service).to receive(:log_attachment_outcome)
      allow(service).to receive(:category_for_successful_attachment)
        .and_return(:successfully_attached)
    end

    it 'attaches all files and logs successful outcomes' do
      service.process_record(record)

      expect(service).to have_received(:attach_pdf_to_work_with_file_path!).with(
        record: record,
        file_path: '/tmp/full_text_pdfs/paper.pdf',
        depositor_onyen: 'test-user'
      )
      expect(service).to have_received(:log_attachment_outcome).with(
        record,
        category: :successfully_attached,
        message: 'PDF successfully attached.',
        file_name: 'paper.pdf'
      )
    end

    it 'logs errors and marks failed attachments when exceptions occur' do
      allow(service).to receive(:attach_pdf_to_work_with_file_path!).and_raise(StandardError, 'file not found')
      service.process_record(record)

      expect(Rails.logger).to have_received(:error).with(/Error processing record abc123: file not found/)
      expect(service).to have_received(:log_attachment_outcome).with(
        record,
        category: :failed,
        message: a_string_including('NSF File Attachment Error: file not found'),
        file_name: nil
      )
    end
  end
end
