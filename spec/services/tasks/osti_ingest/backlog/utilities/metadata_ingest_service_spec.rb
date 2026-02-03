# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::OstiIngest::Backlog::Utilities::MetadataIngestService do
  let(:admin_set) { FactoryBot.create(:admin_set, title: ['OSTI Admin Set']) }
  let(:depositor) { FactoryBot.create(:user) }
  let(:config) do
    {
      'output_dir' => '/tmp/osti_output',
      'data_dir' => '/tmp/osti_data',
      'admin_set_title' => admin_set.title.first,
      'depositor_onyen' => depositor.uid
    }
  end
  let(:tracker) { Tasks::OstiIngest::Backlog::Utilities::OstiIngestTracker.new(config) }
  let(:md_ingest_results_path) { '/tmp/osti_metadata_results.jsonl' }

  subject(:service) do
    described_class.new(
      config: config,
      tracker: tracker,
      md_ingest_results_path: md_ingest_results_path
    )
  end

  before do
    allow(LogUtilsHelper).to receive(:double_log)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
    allow(service).to receive(:sleep)
  end

  describe '#initialize' do
    it 'sets instance variables from config' do
      expect(service.instance_variable_get(:@config)).to eq(config)
      expect(service.instance_variable_get(:@data_dir)).to eq('/tmp/osti_data')
      expect(service.instance_variable_get(:@output_dir)).to eq('/tmp/osti_output')
    end

    it 'initializes empty seen identifier list' do
      expect(service.instance_variable_get(:@seen_identifier_list)).to be_a(Set)
    end
  end

  describe '#identifier_key_name' do
    it 'returns osti_id' do
      expect(service.identifier_key_name).to eq('osti_id')
    end
  end

  describe '#process_backlog' do
    let(:metadata_json) do
      {
        'osti_id' => '123456',
        'doi' => 'https://doi.org/10.1234/test',
        'title' => 'Test Article',
        'description' => 'Test abstract',
        'authors' => ['Doe, John [UNC Chapel Hill]']
      }
    end
    let(:resolver) { instance_double(Tasks::IngestHelperUtils::DoiMetadataResolver) }
    let(:attr_builder) { instance_double(Tasks::IngestHelperUtils::SharedAttributeBuilders::CrossrefAttributeBuilder) }

    before do
      allow(Dir).to receive(:entries).with('/tmp/osti_data').and_return(['.', '..', '123456'])
      allow(File).to receive(:exist?).and_return(true)
      allow(File).to receive(:read).and_return(metadata_json.to_json)
      allow(WorkUtilsHelper).to receive(:fetch_work_data_by_alternate_identifier).and_return(nil)
      allow(WorkUtilsHelper).to receive(:fetch_work_data_by_doi).and_return(nil)
      allow(Tasks::IngestHelperUtils::DoiMetadataResolver).to receive(:new).and_return(resolver)
      allow(resolver).to receive(:resolve_and_build).and_return(attr_builder)
      allow(resolver).to receive(:resolved_metadata).and_return({})
      allow(service).to receive(:new_article).and_return(FactoryBot.build(:article))
      allow(service).to receive(:record_result)
      allow(service).to receive(:flush_buffer_if_needed)
      allow(service).to receive(:flush_buffer_to_file)
    end

    it 'processes all OSTI IDs in data directory' do
      expect(service).to receive(:new_article).once

      service.process_backlog

      expect(LogUtilsHelper).to have_received(:double_log).with(
        'Ingest complete. Processed 1 IDs.',
        :info,
        tag: 'MetadataIngestService'
      )
    end

    it 'skips IDs already in seen list' do
      service.instance_variable_get(:@seen_identifier_list).add('123456')

      expect(service).not_to receive(:new_article)

      service.process_backlog
    end

    it 'skips existing works with matching OSTI ID' do
      allow(WorkUtilsHelper).to receive(:fetch_work_data_by_alternate_identifier)
        .with('123456', admin_set_title: admin_set.title.first)
        .and_return({ work_id: 'existing-123' })

      expect(service).not_to receive(:new_article)

      service.process_backlog
    end

    it 'skips existing works with matching DOI' do
      allow(WorkUtilsHelper).to receive(:fetch_work_data_by_doi)
        .with('https://doi.org/10.1234/test', admin_set_title: admin_set.title.first)
        .and_return({ work_id: 'existing-456' })

      expect(service).not_to receive(:new_article)

      service.process_backlog
    end

    it 'handles errors and continues processing' do
      allow(service).to receive(:metadata_json_for_osti_id).and_raise(StandardError.new('JSON parse error'))
      allow(service).to receive(:handle_record_error)

      service.process_backlog

      expect(service).to have_received(:handle_record_error).with('123456', anything, filename: '123456.pdf')
    end

    it 'respects rate limiting between records' do
      service.process_backlog

      expect(service).to have_received(:sleep).with(3)
    end
  end

  describe '#new_article' do
    let(:attr_builder) { instance_double(Tasks::IngestHelperUtils::SharedAttributeBuilders::CrossrefAttributeBuilder) }
    let(:metadata) do
      {
        'backlog_abstract' => 'Test abstract with <sup>HTML</sup>',
        'authors' => [
          'Doe, John [UNC Chapel Hill]',
          'Smith, Jane [MIT] (ORCID:0000-0001-2345-6789)'
        ]
      }
    end
    let(:article) { FactoryBot.build(:article, title: ['Test <scp>Title</scp>']) }

    before do
      allow(Article).to receive(:new).and_return(article)
      allow(attr_builder).to receive(:populate_article_metadata)
      allow(article).to receive(:save!)
      allow(service).to receive(:sync_permissions_and_state!)
      allow(article.creators).to receive(:clear)
      allow(article).to receive(:creators_attributes=)
    end

    it 'creates new article with OSTI ID in identifiers' do
      service.new_article(metadata: metadata, attr_builder: attr_builder, config: config, osti_id: '123456')

      expect(article.identifier).to include('OSTI ID: 123456')
    end

    it 'uses backlog abstract when present' do
      service.new_article(metadata: metadata, attr_builder: attr_builder, config: config, osti_id: '123456')

      expect(article.abstract).to eq(['Test abstract with <sup>HTML</sup>'])
    end

    it 'strips HTML from title' do
      service.new_article(metadata: metadata, attr_builder: attr_builder, config: config, osti_id: '123456')

      expect(article.title).to eq(['Test Title'])
    end

    it 'replaces creators with OSTI authors' do
      service.new_article(metadata: metadata, attr_builder: attr_builder, config: config, osti_id: '123456')

      expect(article.creators).to have_received(:clear)
      expect(article).to have_received(:creators_attributes=).with([
        { 'name' => 'Doe, John', 'index' => '0', 'other_affiliation' => 'UNC Chapel Hill' },
        { 'name' => 'Smith, Jane', 'index' => '1', 'other_affiliation' => 'MIT', 'orcid' => '0000-0001-2345-6789' }
      ])
    end

    it 'saves article and syncs permissions' do
      service.new_article(metadata: metadata, attr_builder: attr_builder, config: config, osti_id: '123456')

      expect(article).to have_received(:save!)
      expect(service).to have_received(:sync_permissions_and_state!)
    end
  end

  describe '#resolve_attr_builder_and_metadata_for_json' do
    let(:metadata_json) do
      {
        'osti_id' => '123456',
        'doi' => 'https://doi.org/10.1234/test',
        'description' => 'Test abstract',
        'authors' => ['Doe, John [UNC]']
      }
    end
    let(:resolver) { instance_double(Tasks::IngestHelperUtils::DoiMetadataResolver) }
    let(:attr_builder) { instance_double(Tasks::IngestHelperUtils::SharedAttributeBuilders::CrossrefAttributeBuilder) }
    let(:resolved_metadata) { { 'title' => 'Test' } }

    before do
      allow(Tasks::IngestHelperUtils::DoiMetadataResolver).to receive(:new).and_return(resolver)
      allow(resolver).to receive(:resolve_and_build).and_return(attr_builder)
      allow(resolver).to receive(:resolved_metadata).and_return(resolved_metadata)
    end

    it 'resolves metadata using DOI resolver' do
      result_builder, result_metadata = service.resolve_attr_builder_and_metadata_for_json(metadata_json)

      expect(result_builder).to eq(attr_builder)
      expect(result_metadata['backlog_abstract']).to eq('Test abstract')
      expect(result_metadata['authors']).to eq(['Doe, John [UNC]'])
    end

    it 'raises error when OSTI ID is blank' do
      metadata_json['osti_id'] = ''

      expect {
        service.resolve_attr_builder_and_metadata_for_json(metadata_json)
      }.to raise_error(ArgumentError, 'OSTI ID cannot be blank')
    end

    it 'raises error when DOI is missing' do
      metadata_json['doi'] = nil

      expect {
        service.resolve_attr_builder_and_metadata_for_json(metadata_json)
      }.to raise_error(ArgumentError, /No DOI present/)
    end

    it 'logs and re-raises errors during resolution' do
      allow(resolver).to receive(:resolve_and_build).and_raise(StandardError.new('API error'))

      expect {
        service.resolve_attr_builder_and_metadata_for_json(metadata_json)
      }.to raise_error(StandardError)

      expect(Rails.logger).to have_received(:error).with(/Error resolving metadata/)
    end
  end

  describe 'author parsing' do
    let(:attr_builder) { instance_double(Tasks::IngestHelperUtils::SharedAttributeBuilders::CrossrefAttributeBuilder) }
    let(:article) { FactoryBot.build(:article) }

    before do
      allow(Article).to receive(:new).and_return(article)
      allow(attr_builder).to receive(:populate_article_metadata)
      allow(article).to receive(:save!)
      allow(service).to receive(:sync_permissions_and_state!)
      allow(article.creators).to receive(:clear)
      allow(article).to receive(:creators_attributes=)
    end

    it 'parses authors with affiliations' do
      metadata = {
        'authors' => ['Doe, John [UNC Chapel Hill]']
      }

      service.new_article(metadata: metadata, attr_builder: attr_builder, config: config, osti_id: '123')

      expect(article).to have_received(:creators_attributes=).with([
        { 'name' => 'Doe, John', 'index' => '0', 'other_affiliation' => 'UNC Chapel Hill' }
      ])
    end

    it 'parses authors with affiliations and ORCIDs' do
      metadata = {
        'authors' => ['Smith, Jane [MIT] (ORCID:0000-0001-2345-6789)']
      }

      service.new_article(metadata: metadata, attr_builder: attr_builder, config: config, osti_id: '123')

      expect(article).to have_received(:creators_attributes=).with([
        { 'name' => 'Smith, Jane', 'index' => '0', 'other_affiliation' => 'MIT', 'orcid' => '0000-0001-2345-6789' }
      ])
    end

    it 'parses authors without affiliations' do
      metadata = {
        'authors' => ['Brown, Bob']
      }

      service.new_article(metadata: metadata, attr_builder: attr_builder, config: config, osti_id: '123')

      expect(article).to have_received(:creators_attributes=).with([
        { 'name' => 'Brown, Bob', 'index' => '0' }
      ])
    end

    it 'handles multiple authors with mixed formats' do
      metadata = {
        'authors' => [
          'Doe, John [UNC]',
          'Smith, Jane [MIT] (ORCID:1234)',
          'Brown, Bob'
        ]
      }

      service.new_article(metadata: metadata, attr_builder: attr_builder, config: config, osti_id: '123')

      expect(article).to have_received(:creators_attributes=).with([
        { 'name' => 'Doe, John', 'index' => '0', 'other_affiliation' => 'UNC' },
        { 'name' => 'Smith, Jane', 'index' => '1', 'other_affiliation' => 'MIT', 'orcid' => '1234' },
        { 'name' => 'Brown, Bob', 'index' => '2' }
      ])
    end
  end

  describe 'HTML sanitization' do
    let(:attr_builder) { instance_double(Tasks::IngestHelperUtils::SharedAttributeBuilders::CrossrefAttributeBuilder) }
    let(:article) { FactoryBot.build(:article, title: ['Title with <sup>HTML</sup> tags']) }

    before do
      allow(Article).to receive(:new).and_return(article)
      allow(attr_builder).to receive(:populate_article_metadata)
      allow(article).to receive(:save!)
      allow(service).to receive(:sync_permissions_and_state!)
      allow(article.creators).to receive(:clear)
      allow(article).to receive(:creators_attributes=)
    end

    it 'removes HTML tags from title' do
      metadata = { 'authors' => [] }

      service.new_article(metadata: metadata, attr_builder: attr_builder, config: config, osti_id: '123')

      expect(article.title).to eq(['Title with HTML tags'])
    end

    it 'strips HTML from abstract' do
      metadata = {
        'backlog_abstract' => '<p>Abstract with <strong>bold</strong> and <em>italic</em></p>',
        'authors' => []
      }

      service.new_article(metadata: metadata, attr_builder: attr_builder, config: config, osti_id: '123')

      expect(article.abstract).to eq(['<p>Abstract with <strong>bold</strong> and <em>italic</em></p>'])
    end

    it 'handles nil abstract' do
      metadata = {
        'backlog_abstract' => nil,
        'authors' => []
      }

      service.new_article(metadata: metadata, attr_builder: attr_builder, config: config, osti_id: '123')

      expect(article.abstract).to eq([])
    end
  end
end
