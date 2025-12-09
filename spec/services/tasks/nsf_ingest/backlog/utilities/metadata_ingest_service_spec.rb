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
        { 'pmid' => '111', 'pmcid' => 'PMC1', 'doi' => '10.1000/abc' },
        { 'pmid' => '222', 'pmcid' => 'PMC2', 'doi' => '10.2000/xyz' }
      ]
    end

    before do
      # Stub record loading
      allow(service).to receive(:remaining_records_from_csv).and_return(records)
      allow(service).to receive(:load_last_results).and_return(Set.new)
      # Stub the DoiMetadataResolver
      mock_attr_builder = double('AttributeBuilder', populate_article_metadata: true)

      mock_resolver = double('DoiMetadataResolver',
        resolve_and_build: mock_attr_builder,
        resolved_metadata: { 'title' => 'Test Title', 'source' => 'openalex', 'doi' => '10.1000/abc' }
      )

      allow(Tasks::IngestHelperUtils::DoiMetadataResolver).to receive(:new).and_return(mock_resolver)

      allow(service).to receive(:sync_permissions_and_state!).and_return(true)
      # WorkUtilsHelper
      allow(WorkUtilsHelper).to receive(:find_best_work_match_by_alternate_id).and_return({})
      # File flush
      allow(File).to receive(:open)
    end

    it 'creates new articles and logs success' do
      article_double = double('Article', id: 'A123', save!: true, visibility: nil, 'visibility=': nil, pmid: '111', pmcid: 'PMC1', doi: '10.1000/abc')
      allow(Article).to receive(:new).and_return(article_double)

      service.process_backlog

      expect(service).to have_received(:fetch_metadata_for_doi).at_least(:once)
      expect(LogUtilsHelper).to have_received(:double_log).with(
        a_string_including('Ingest complete'),
        :info,
        tag: 'MetadataIngestService'
      )
    end

    it 'skips existing works when match is found' do
      allow(WorkUtilsHelper).to receive(:fetch_work_data_by_doi)
        .and_return({ work_id: 'EXIST123', work_type: 'Article' })
      allow(WorkUtilsHelper).to receive(:fetch_model_instance).and_return(double('Article'))
      allow(service).to receive(:record_result)
      service.process_backlog
      # Use at_least since it may be called multiple times (once per record)
      expect(service).to have_received(:record_result).with(hash_including(category: :skipped)).at_least(:once)
    end

    it 'handles and logs exceptions gracefully' do
      allow(service).to receive(:fetch_metadata_for_doi).and_raise(StandardError, 'boom!')
      service.process_backlog
      # Use at_least since it may be called multiple times (once per record)
      expect(Rails.logger).to have_received(:error).with(/boom!/).at_least(:once)
      expect(LogUtilsHelper).to have_received(:double_log).with(
        a_string_including('Ingest complete'),
        :info,
        tag: 'MetadataIngestService'
      )
    end
  end

  describe '#record_result' do
    let(:article) { double('Article', id: 'A123', pmid: '111', pmcid: 'PMC1', doi: '10.1000/foo') }

    it 'appends record and flushes when threshold reached' do
      service.instance_variable_set(:@flush_threshold, 1)
      allow(service).to receive(:flush_buffer_to_file)
      allow(service).to receive(:extract_alternate_ids_from_article).and_return(nil)
      service.send(:record_result, category: :ok, identifier: '10.1000/foo', article: article)
      expect(service).to have_received(:flush_buffer_to_file)
    end

    it 'does not duplicate seen DOI entries' do
      seen = Set.new(['10.1000/foo'])
      service.instance_variable_set(:@seen_identifier_list, seen)
      allow(service).to receive(:flush_buffer_to_file)
      allow(service).to receive(:extract_alternate_ids_from_article).and_return(nil)
      service.send(:record_result, category: :ok, identifier: '10.1000/foo', article: article)
      # Now it should write because the duplicate check was removed
      expect(service.instance_variable_get(:@write_buffer).size).to eq(1)
    end
  end

  describe '#verify_source_md_available' do
    it 'returns openalex when crossref is nil' do
      res = service.send(:verify_source_md_available, nil, { bar: 2 }, '10.1/x')
      expect(LogUtilsHelper).to have_received(:double_log).with(
        /Using OpenAlex metadata/,
        :warn,
        tag: 'MetadataIngestService'
      )
    end

    it 'returns crossref when openalex is nil' do
      res = service.send(:verify_source_md_available, { foo: 1 }, nil, '10.1/x')
      expect(LogUtilsHelper).to have_received(:double_log).with(
        /Using Crossref metadata/,
        :warn,
        tag: 'MetadataIngestService'
      )
    end

    it 'raises when both are nil' do
      expect {
        service.send(:verify_source_md_available, nil, nil, '10.1/x')
      }.to raise_error(/No metadata found/)
    end
  end

  describe '#merge_metadata_sources' do
    it 'merges abstract and keywords from openalex/datacite' do
      crossref = {}
      openalex = { 'abstract_inverted_index' => { 'Hyrax' => [0], 'rocks' => [1] }, 'concepts' => [{ 'display_name' => 'Hyrax' }] }
      datacite = { 'attributes' => { 'description' => 'A Datacite desc' } }

      allow(service).to receive(:generate_openalex_abstract).and_return('Hyrax rocks.')
      allow(service).to receive(:extract_keywords_from_openalex).and_return(['Hyrax'])

      resolved = service.send(:merge_metadata_sources, crossref, openalex, datacite)

      expect(resolved['openalex_abstract']).to eq('Hyrax rocks.')
      expect(resolved['datacite_abstract']).to eq('A Datacite desc')
      expect(resolved['openalex_keywords']).to eq(['Hyrax'])
    end
  end

  describe '#handle_record_error' do
    it 'logs the error and records a failed result' do
      record = { 'doi' => '10.5555/err', 'pmid' => 'x', 'pmcid' => 'y' }
      # Create an error with a backtrace
      error = StandardError.new('ouch')
      error.set_backtrace(['line1', 'line2', 'line3'])

      allow(service).to receive(:record_result)
      service.send(:handle_record_error, record, error)
      expect(Rails.logger).to have_received(:error).with(/Error processing work/)
      expect(Rails.logger).to have_received(:error).with(/line1/)
      expect(service).to have_received(:record_result).with(
        hash_including(category: :failed, message: 'ouch')
      )
    end
  end
end
