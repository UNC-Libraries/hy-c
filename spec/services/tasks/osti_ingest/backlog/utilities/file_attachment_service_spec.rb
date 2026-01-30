# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::OstiIngest::Backlog::Utilities::FileAttachmentService do
  let (:admin_set) { FactoryBot.create(:admin_set) }
  let (:depositor) { FactoryBot.create(:user) }
  let (:file_set) { FactoryBot.build(:file_set) }
  let (:config) do
    {
        'start_time' => DateTime.new(2024, 1, 1),
        'restart_time' => nil,
        'resume' => false,
        'admin_set_title' => admin_set.title,
        'depositor_onyen' => depositor.uid,
        'output_dir' => '/tmp/osti_output',
        'data_dir' => '/tmp/osti_data'
    }
  end
  let (:tracker) { Tasks::OstiIngest::Backlog::Utilities::OstiIngestTracker.new(config) }
  let (:log_file_path) { '/tmp/osti_attachment_log.csv' }
  let (:metadata_ingest_result_path) { '/tmp/osti_metadata_ingest_results.csv' }
  subject(:service) do
    described_class.new(
        config: config,
        tracker: tracker,
        log_file_path: log_file_path,
        metadata_ingest_result_path: metadata_ingest_result_path
    )
  end

  describe '#process_record' do
    let(:record) do
      {
            'ids' => {
                'work_id' => '12345',
                'osti_id' => '1987654'
            }
        }
    end

    before do
      allow(Dir).to receive(:glob). and_call_original
      allow(Dir).to receive(:glob).with('/tmp/osti_data/1987654/*.pdf')
                                   .and_return(['/tmp/osti_data/1987654/1987654.pdf'])
      allow(service).to receive(:attach_pdf_to_work_with_file_path!).and_return(file_set)
      allow(service).to receive(:log_attachment_outcome)
    end

    it 'attaches the PDF and logs the outcome' do
      service.process_record(record)

      expect(service).to have_received(:attach_pdf_to_work_with_file_path!).with(
          record: record,
          file_path: '/tmp/osti_data/1987654/1987654.pdf',
          depositor_onyen: depositor.uid
      )
      expect(service).to have_received(:log_attachment_outcome).with(
          record,
          category: :successfully_ingested_and_attached,
          message: 'PDF successfully attached.',
          file_name: '1987654.pdf'
      )
    end

    it 'handles errors during processing and logs failure' do
      allow(service).to receive(:attach_pdf_to_work_with_file_path!).and_raise(StandardError.new('Attachment error'))
      allow(Rails.logger).to receive(:error)

      service.process_record(record)

      expect(Rails.logger).to have_received(:error).with(/Error processing record 12345: Attachment error/)
      expect(service).to have_received(:log_attachment_outcome).with(
          record,
          category: :failed,
          message: 'OSTI File Attachment Error: Attachment error',
          file_name: '1987654.pdf'
      )
    end

    context 'when no PDF files exist' do
      before do
        allow(Dir).to receive(:glob).with('/tmp/osti_data/1987654/*.pdf')
          .and_return([])
      end

      it 'logs as successfully ingested metadata only' do
        service.process_record(record)

        expect(service).to have_received(:log_attachment_outcome).with(
          record,
          category: :successfully_ingested_metadata_only,
          message: 'No PDF files found in directory',
          file_name: 'N/A'
        )
      end
    end
  end
end
