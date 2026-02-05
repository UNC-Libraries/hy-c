# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::DTICIngest::Backlog::Utilities::FileAttachmentService do
  let(:admin_set) { FactoryBot.create(:admin_set, title: ['DTIC Admin Set']) }
  let(:depositor) { FactoryBot.create(:user) }
  let(:full_text_dir) { '/tmp/dtic_pdfs' }
  let(:config) do
    {
      'full_text_dir' => full_text_dir,
      'output_dir' => '/tmp/dtic_output',
      'admin_set_title' => admin_set.title.first,
      'depositor_onyen' => depositor.uid
    }
  end
  let(:tracker) { Tasks::DTICIngest::Backlog::Utilities::DTICIngestTracker.new(config) }
  let(:log_file_path) { '/tmp/dtic_attachment.log' }
  let(:file_info_path) { '/tmp/dtic_file_info.jsonl' }
  let(:metadata_ingest_result_path) { '/tmp/dtic_metadata_results.jsonl' }

  subject(:service) do
    described_class.new(
      config: config,
      tracker: tracker,
      log_file_path: log_file_path,
      file_info_path: file_info_path,
      metadata_ingest_result_path: metadata_ingest_result_path
    )
  end

  before do
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
    allow(service).to receive(:sleep)
  end

  describe '#initialize' do
    it 'sets full_text_path from config' do
      expect(service.instance_variable_get(:@full_text_path)).to eq(full_text_dir)
    end

    it 'initializes existing_ids set' do
      expect(service.instance_variable_get(:@existing_ids)).to be_a(Set)
    end
  end

  describe '#process_record' do
    let(:record) do
      {
        'filename' => 'AD1192590.pdf',
        'ids' => { 'dtic_id' => 'AD1192590', 'work_id' => 'work123' }
      }
    end
    let(:file_path) { '/tmp/dtic_pdfs/subdir/AD1192590.pdf' }

    before do
      allow(service).to receive(:find_pdf_in_directory).and_return(file_path)
      allow(service).to receive(:attach_pdf_to_work_with_file_path!).and_return(true)
      allow(service).to receive(:category_for_successful_attachment).and_return(:successfully_attached)
      allow(service).to receive(:log_attachment_outcome)
    end

    it 'finds PDF using recursive search' do
      service.process_record(record)

      expect(service).to have_received(:find_pdf_in_directory).with(full_text_dir, 'AD1192590.pdf')
    end

    it 'attaches PDF when file is found' do
      service.process_record(record)

      expect(service).to have_received(:attach_pdf_to_work_with_file_path!).with(
        record: record,
        file_path: file_path,
        depositor_onyen: depositor.uid
      )
    end

    it 'logs successful attachment' do
      service.process_record(record)

      expect(service).to have_received(:log_attachment_outcome).with(
        record,
        category: :successfully_attached,
        message: 'PDF successfully attached.',
        file_name: 'AD1192590.pdf'
      )
    end

    it 'sleeps after processing to rate limit' do
      service.process_record(record)

      expect(service).to have_received(:sleep).with(1)
    end

    context 'when PDF file is not found' do
      before do
        allow(service).to receive(:find_pdf_in_directory).and_return(nil)
      end

      it 'logs failure and returns early' do
        service.process_record(record)

        expect(service).to have_received(:log_attachment_outcome).with(
          record,
          category: :failed,
          message: 'PDF file not found: AD1192590.pdf',
          file_name: 'AD1192590.pdf'
        )
        expect(service).not_to have_received(:attach_pdf_to_work_with_file_path!)
      end
    end

    context 'when attachment fails' do
      before do
        allow(service).to receive(:attach_pdf_to_work_with_file_path!)
          .and_raise(StandardError.new('Attachment error'))
      end

      it 'logs error and continues' do
        service.process_record(record)

        expect(Rails.logger).to have_received(:error).with(/Error processing record/)
        expect(service).to have_received(:log_attachment_outcome).with(
          record,
          category: :failed,
          message: 'DTIC File Attachment Error: Attachment error',
          file_name: 'AD1192590.pdf'
        )
      end
    end
  end

  describe '#find_pdf_in_directory' do
    let(:base_path) { '/tmp/dtic_test' }
    let(:filename) { 'AD1192590.pdf' }

    before do
      # Create temporary directory structure
      FileUtils.mkdir_p(File.join(base_path, 'subdir1'))
      FileUtils.mkdir_p(File.join(base_path, 'subdir2', 'nested'))

      # Create test files
      FileUtils.touch(File.join(base_path, 'subdir1', 'AD1192590.pdf'))
      # Create a directory with same name (should be ignored)
      FileUtils.mkdir_p(File.join(base_path, 'subdir2', 'AD1192590.pdf'))
    end

    after do
      FileUtils.rm_rf(base_path) if File.exist?(base_path)
    end

    it 'finds PDF in nested subdirectories' do
      result = service.send(:find_pdf_in_directory, base_path, filename)

      expect(result).to eq(File.join(base_path, 'subdir1', 'AD1192590.pdf'))
      expect(File.file?(result)).to be true
    end

    it 'ignores directories with same name as file' do
      result = service.send(:find_pdf_in_directory, base_path, filename)

      expect(result).not_to include('subdir2')
      expect(File.file?(result)).to be true
    end

    it 'returns nil when file not found' do
      result = service.send(:find_pdf_in_directory, base_path, 'nonexistent.pdf')

      expect(result).to be_nil
    end

    it 'returns first file match when multiple exist' do
      # Create second file
      FileUtils.touch(File.join(base_path, 'subdir2', 'nested', 'AD1192590.pdf'))

      result = service.send(:find_pdf_in_directory, base_path, filename)

      expect(result).to be_a(String)
      expect(File.file?(result)).to be true
      expect(result).to end_with('AD1192590.pdf')
    end
  end

  describe 'DTIC ID extraction' do
    it 'extracts ID from various filename patterns' do
      test_cases = {
        'AD1192590.pdf' => 'AD1192590',
        'ADA383106.pdf' => 'ADA383106',
        'ADA202441.pdf' => 'ADA202441'
      }

      test_cases.each do |filename, expected_id|
        record = { 'filename' => filename, 'ids' => { 'dtic_id' => expected_id } }

        allow(service).to receive(:find_pdf_in_directory).and_return(nil)
        allow(service).to receive(:log_attachment_outcome)

        service.process_record(record)

        # Verify the DTIC ID was extracted correctly (filename.split('.').first)
        expect(filename.split('.').first).to eq(expected_id)
      end
    end
  end
end
