# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::NASAIngest::Backlog::Utilities::FileAttachmentService do
  let(:admin_set) { FactoryBot.create(:admin_set, title: ['NASA Admin Set']) }
  let(:depositor) { FactoryBot.create(:user) }
  let(:data_dir) { '/tmp/nasa_data' }
  let(:config) do
    {
      'data_dir' => data_dir,
      'output_dir' => '/tmp/nasa_output',
      'admin_set_title' => admin_set.title.first,
      'depositor_onyen' => depositor.uid
    }
  end
  let(:tracker) { Tasks::NASAIngest::Backlog::Utilities::NASAIngestTracker.new(config) }
  let(:log_file_path) { '/tmp/nasa_attachment.log' }
  let(:metadata_ingest_result_path) { '/tmp/nasa_metadata_results.jsonl' }

  subject(:service) do
    described_class.new(
      config: config,
      tracker: tracker,
      log_file_path: log_file_path,
      metadata_ingest_result_path: metadata_ingest_result_path
    )
  end

  let(:work) { FactoryBot.create(:article, admin_set: admin_set) }
  
  let(:record) do
    {
      'ids' => {
        'nasa_id' => '20230015324',
        'work_id' => work.id
      }
    }
  end

  before do
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
    allow(service).to receive(:sleep)

    # Create data directory structure with PDFs
    FileUtils.mkdir_p(File.join(data_dir, '20230015324'))
    FileUtils.touch(File.join(data_dir, '20230015324', 'main_document.pdf'))
    FileUtils.touch(File.join(data_dir, '20230015324', 'supplemental.pdf'))
  end

  after do
    FileUtils.rm_rf(data_dir) if File.exist?(data_dir)
  end

  describe '#initialize' do
    it 'sets data_dir from config' do
      expect(service.instance_variable_get(:@data_dir)).to eq(data_dir)
    end

    it 'initializes existing_ids' do
      expect(service.instance_variable_get(:@existing_ids)).to be_a(Set)
    end
  end

  describe '#process_record' do
    before do
      allow(service).to receive(:attach_pdf_to_work_with_file_path!).and_return(true)
      allow(service).to receive(:log_attachment_outcome)
      allow(service).to receive(:category_for_successful_attachment).and_return(:successfully_attached)
    end

    it 'attaches all PDFs in the directory' do
      service.process_record(record)

      expect(service).to have_received(:attach_pdf_to_work_with_file_path!).twice
    end

    it 'logs successful attachment for each PDF' do
      service.process_record(record)

      expect(service).to have_received(:log_attachment_outcome).with(
        record,
        hash_including(
          category: :successfully_attached,
          message: 'PDF successfully attached.',
          file_name: 'main_document.pdf'
        )
      )
      expect(service).to have_received(:log_attachment_outcome).with(
        record,
        hash_including(
          category: :successfully_attached,
          message: 'PDF successfully attached.',
          file_name: 'supplemental.pdf'
        )
      )
    end

    it 'sleeps between file attachments' do
      service.process_record(record)

      expect(service).to have_received(:sleep).with(1).twice
    end

    it 'logs failure when directory does not exist' do
      record['ids']['nasa_id'] = 'nonexistent'
      
      service.process_record(record)

      expect(service).to have_received(:log_attachment_outcome).with(
        record,
        hash_including(
          category: :failed,
          message: 'Directory not found for NASA ID: nonexistent',
          file_name: 'nonexistent'
        )
      )
    end

    it 'logs failure when no PDF files found' do
      # Remove all PDFs
      Dir.glob(File.join(data_dir, '20230015324', '*.pdf')).each { |f| File.delete(f) }
      
      service.process_record(record)

      expect(service).to have_received(:log_attachment_outcome).with(
        record,
        hash_including(
          category: :failed,
          message: /No PDF files found/,
          file_name: '20230015324'
        )
      )
    end

    it 'passes correct file path to attachment method' do
      service.process_record(record)

      expect(service).to have_received(:attach_pdf_to_work_with_file_path!).with(
        hash_including(
          record: record,
          file_path: File.join(data_dir, '20230015324', 'main_document.pdf'),
          depositor_onyen: depositor.uid
        )
      )
    end

    it 'handles attachment errors gracefully' do
      allow(service).to receive(:attach_pdf_to_work_with_file_path!)
        .and_raise(StandardError.new('Attachment failed'))

      service.process_record(record)

      expect(service).to have_received(:log_attachment_outcome).with(
        record,
        hash_including(
          category: :failed,
          message: /NASA File Attachment Error: Attachment failed/
        )
      )
    end

    it 'logs error details when exception occurs' do
      error = StandardError.new('Test error')
      allow(service).to receive(:attach_pdf_to_work_with_file_path!).and_raise(error)

      service.process_record(record)

      expect(Rails.logger).to have_received(:error).with(/Error processing record 20230015324/)
      expect(Rails.logger).to have_received(:error).with(error.backtrace.join("\n"))
    end

    it 'continues processing after failed attachment' do
      allow(service).to receive(:attach_pdf_to_work_with_file_path!)
        .and_return(nil)

      expect { service.process_record(record) }.not_to raise_error
    end

    it 'processes PDFs in directory order' do
      call_order = []
      allow(service).to receive(:attach_pdf_to_work_with_file_path!) do |args|
        call_order << File.basename(args[:file_path])
        true
      end

      service.process_record(record)

      expect(call_order.length).to eq(2)
      expect(call_order).to include('main_document.pdf', 'supplemental.pdf')
    end

    context 'with single PDF' do
      before do
        Dir.glob(File.join(data_dir, '20230015324', '*.pdf')).each { |f| File.delete(f) }
        FileUtils.touch(File.join(data_dir, '20230015324', 'single.pdf'))
      end

      it 'attaches single PDF successfully' do
        service.process_record(record)

        expect(service).to have_received(:attach_pdf_to_work_with_file_path!).once
        expect(service).to have_received(:log_attachment_outcome).with(
          record,
          hash_including(file_name: 'single.pdf')
        )
      end
    end
  end
end