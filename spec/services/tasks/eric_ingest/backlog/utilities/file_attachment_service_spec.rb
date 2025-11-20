# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::EricIngest::Backlog::Utilities::FileAttachmentService do
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
        'output_dir' => '/tmp/eric_output',
        'full_text_dir' => '/tmp/eric_full_text'
    }
  end
  let (:tracker) { Tasks::EricIngest::Backlog::Utilities::EricIngestTracker.new(config) }
  let (:log_file_path) { '/tmp/eric_attachment_log.csv' }
  let (:metadata_ingest_result_path) { '/tmp/eric_metadata_ingest_results.csv' }
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
                'eric_id' => 'ED987654'
            }
        }
    end

    before do
      allow(service).to receive(:attach_pdf_to_work_with_file_path!).and_return(file_set)
      allow(service).to receive(:log_attachment_outcome)
    end

    it 'attaches the PDF and logs the outcome' do
      service.process_record(record)

      expect(service).to have_received(:attach_pdf_to_work_with_file_path!).with(
          record: record,
          file_path: '/tmp/eric_full_text/ED987654.pdf',
          depositor_onyen: depositor.uid
      )
      expect(service).to have_received(:log_attachment_outcome).with(
          record,
          category: :successfully_ingested_and_attached,
          message: 'PDF successfully attached.',
          file_name: 'ED987654.pdf'
      )
    end

    it 'handles errors during processing and logs failure' do
      allow(service).to receive(:attach_pdf_to_work_with_file_path!).and_raise(StandardError.new('File not found'))
      allow(Rails.logger).to receive(:error)

      service.process_record(record)

      expect(Rails.logger).to have_received(:error).with(/Error processing record 12345: File not found/)
      expect(service).to have_received(:log_attachment_outcome).with(
          record,
          category: :failed,
          message: 'ERIC File Attachment Error: File not found',
          file_name: 'ED987654.pdf'
      )
    end
  end
end
