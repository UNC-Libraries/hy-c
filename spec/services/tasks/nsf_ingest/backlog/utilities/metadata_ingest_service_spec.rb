# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::NsfIngest::Backlog::Utilities::MetadataIngestService do
  let(:config) do
    {
      'depositor_onyen' => 'test-user',
      'file_info_csv_path' => '/tmp/nsf_file_info.csv',
      'output_dir' => '/tmp/nsf_output',
      'admin_set_title' => 'NSF Admin Set'
    }
  end
  let(:tracker) { double('Tracker', save: true) }
  let(:md_ingest_results_path) { '/tmp/md_results.jsonl' }
  let(:admin_set) { double('AdminSet', id: 'set1') }

  subject(:service) do
    described_class.new(config: config, tracker: tracker, md_ingest_results_path: md_ingest_results_path)
  end

  before do
    allow(AdminSet).to receive(:where).and_return([admin_set])
    allow(File).to receive(:exist?).and_return(false)
    allow(File).to receive(:open)
    allow(File).to receive(:readlines).and_return([])
    allow(Rails.logger).to receive(:error)
    allow(Rails.logger).to receive(:info)
    allow(LogUtilsHelper).to receive(:double_log)
  end

  describe '#initialize' do
    it 'sets expected instance variables and loads seen DOI list' do
      expect(service.instance_variable_get(:@file_info_csv_path)).to eq('/tmp/nsf_file_info.csv')
      expect(service.instance_variable_get(:@output_dir)).to eq('/tmp/nsf_output')
      expect(service.instance_variable_get(:@md_ingest_results_path)).to eq('/tmp/md_results.jsonl')
      expect(service.instance_variable_get(:@tracker)).to eq(tracker)
      expect(service.instance_variable_get(:@seen_identifier_list)).to be_a(Set)
      expect(service.instance_variable_get(:@write_buffer)).to eq([])
    end
  end

  describe '#process_backlog' do
    let(:records) do
      [
        { 'pmid' => '111', 'pmcid' => 'PMC1', 'doi' => '10.1000/abc', 'filename' => 'file1.pdf' },
        { 'pmid' => '222', 'pmcid' => 'PMC2', 'doi' => '10.2000/xyz', 'filename' => 'file2.pdf' }
      ]
    end

    before do
      # Stub record loading
      allow(service).to receive(:remaining_records_from_csv).and_return(records)

      # Stub the DoiMetadataResolver
      mock_attr_builder = double('AttributeBuilder', populate_article_metadata: true)
      mock_resolver = double('DoiMetadataResolver',
        resolve_and_build: mock_attr_builder,
        resolved_metadata: { 'title' => 'Test Title', 'source' => 'openalex', 'doi' => '10.1000/abc' }
      )
      allow(Tasks::IngestHelperUtils::DoiMetadataResolver).to receive(:new).and_return(mock_resolver)

      allow(service).to receive(:sync_permissions_and_state!).and_return(true)
      allow(WorkUtilsHelper).to receive(:fetch_work_data_by_doi).and_return({})
      allow(File).to receive(:open)
    end

    it 'creates new articles and logs success' do
      article_double = double('Article',
        id: 'A123',
        save!: true,
        visibility: Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE,
        'visibility=': nil
      )
      allow(Article).to receive(:new).and_return(article_double)

      service.process_backlog

      expect(Tasks::IngestHelperUtils::DoiMetadataResolver).to have_received(:new).at_least(:once)
      expect(LogUtilsHelper).to have_received(:double_log).with(
        a_string_including('Ingest complete'),
        :info,
        tag: 'MetadataIngestService'
      )
    end

    it 'skips existing works when match is found' do
      allow(WorkUtilsHelper).to receive(:fetch_work_data_by_doi)
        .and_return({ work_id: 'EXIST123', work_type: 'Article' })
      allow(service).to receive(:skip_existing_work)

      service.process_backlog

      expect(service).to have_received(:skip_existing_work).at_least(:once)
    end

    it 'handles and logs exceptions gracefully' do
      allow(Tasks::IngestHelperUtils::DoiMetadataResolver).to receive(:new)
        .and_raise(StandardError, 'boom!')

      service.process_backlog

      expect(Rails.logger).to have_received(:error).with(/boom!/).at_least(:once)
      expect(LogUtilsHelper).to have_received(:double_log).with(
        a_string_including('Ingest complete'),
        :info,
        tag: 'MetadataIngestService'
      )
    end
  end

  describe '#record_result' do
    let(:article) { double('Article', id: 'A123', doi: '10.1000/foo') }

    it 'appends record and flushes when threshold reached' do
      service.instance_variable_set(:@flush_threshold, 1)
      allow(service).to receive(:flush_buffer_to_file)
      service.send(:record_result, category: :ok, identifier: '10.1000/foo', article: article, filename: 'test.pdf')
      expect(service).to have_received(:flush_buffer_to_file)
    end
  end
  describe '#handle_record_error' do
    it 'logs the error and records a failed result' do
      doi = '10.5555/err'
      error = StandardError.new('ouch')
      error.set_backtrace(['line1', 'line2', 'line3'])

      allow(service).to receive(:record_result)
      service.send(:handle_record_error, doi, error, filename: 'test.pdf')

      expect(Rails.logger).to have_received(:error).with(/Error processing work/)
      expect(Rails.logger).to have_received(:error).with(/line1/)
      expect(service).to have_received(:record_result).with(
        hash_including(category: :failed, message: 'ouch')
      )
    end
  end
end
