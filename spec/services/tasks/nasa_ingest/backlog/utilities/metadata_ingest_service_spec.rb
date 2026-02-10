# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::NASAIngest::Backlog::Utilities::MetadataIngestService do
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
  let(:md_ingest_results_path) { '/tmp/nasa_metadata_results.jsonl' }

  subject(:service) do
    described_class.new(
      config: config,
      tracker: tracker,
      md_ingest_results_path: md_ingest_results_path
    )
  end

  let(:sample_metadata) do
    {
      'id' => 20230015324,
      'title' => 'Using Regionalized Air Quality Model Performance',
      'abstract' => 'Test abstract content',
      'distributionDate' => '2023-10-13T04:00:00.0000000+00:00',
      'keywords' => ['Ozone', 'Data fusion'],
      'authorAffiliations' => [
        {
          'sequence' => 0,
          'meta' => {
            'author' => { 'name' => 'Jacob S. Becker' },
            'organization' => { 'name' => 'University of North Carolina at Chapel Hill' }
          }
        }
      ],
      'publications' => [
        {
          'publisher' => 'University of California Press',
          'eissn' => '2325-1026',
          'doi' => '10.1525/elementa.2022.00025',
          'publicationName' => 'Elementa Science of the Anthropocene',
          'volume' => '11'
        }
      ]
    }
  end

  before do
    allow(LogUtilsHelper).to receive(:double_log)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)

    # Create data directory structure
    FileUtils.mkdir_p(data_dir)
    FileUtils.mkdir_p(File.join(data_dir, '20230015324'))
    File.write(File.join(data_dir, '20230015324', 'metadata.json'), sample_metadata.to_json)
  end

  after do
    FileUtils.rm_rf(data_dir) if File.exist?(data_dir)
  end

  describe '#initialize' do
    it 'sets instance variables from config' do
      expect(service.instance_variable_get(:@config)).to eq(config)
      expect(service.instance_variable_get(:@data_dir)).to eq(data_dir)
      expect(service.instance_variable_get(:@output_dir)).to eq('/tmp/nasa_output')
    end

    it 'initializes empty seen identifier list' do
      expect(service.instance_variable_get(:@seen_identifier_list)).to be_a(Set)
    end
  end

  describe '#identifier_key_name' do
    it 'returns nasa_id' do
      expect(service.identifier_key_name).to eq('nasa_id')
    end
  end

  describe '#process_backlog' do
    let(:attr_builder) { instance_double(Tasks::NASAIngest::Backlog::Utilities::AttributeBuilders::NASAAttributeBuilder) }

    before do
      allow(WorkUtilsHelper).to receive(:fetch_work_data_by_alternate_identifier).and_return(nil)
      allow(Tasks::NASAIngest::Backlog::Utilities::AttributeBuilders::NASAAttributeBuilder).to receive(:new).and_return(attr_builder)
      allow(service).to receive(:new_article).and_return(FactoryBot.build(:article))
      allow(service).to receive(:record_result)
      allow(service).to receive(:flush_buffer_if_needed)
      allow(service).to receive(:flush_buffer_to_file)
      allow(service).to receive(:sleep)
    end

    it 'processes all directories from data_dir' do
      expect(service).to receive(:new_article).once

      service.process_backlog

      expect(LogUtilsHelper).to have_received(:double_log).with(
        'Ingest complete. Processed 1 IDs.',
        :info,
        tag: 'MetadataIngestService'
      )
    end

    it 'skips IDs already in seen list' do
      service.instance_variable_get(:@seen_identifier_list).add('20230015324')

      expect(service).not_to receive(:new_article)

      service.process_backlog
    end

    it 'skips existing works with matching NASA ID' do
      allow(WorkUtilsHelper).to receive(:fetch_work_data_by_alternate_identifier)
        .with('20230015324', admin_set_title: admin_set.title.first)
        .and_return({ work_id: 'existing-123' })
      allow(service).to receive(:skip_existing_work)

      expect(service).not_to receive(:new_article)

      service.process_backlog
    end

    it 'creates attribute builder for each record' do
      service.process_backlog

      expect(Tasks::NASAIngest::Backlog::Utilities::AttributeBuilders::NASAAttributeBuilder)
        .to have_received(:new).once
    end

    it 'handles errors and continues processing' do
      allow(service).to receive(:new_article).and_raise(StandardError.new('Test error'))
      allow(service).to receive(:handle_record_error)

      service.process_backlog

      expect(service).to have_received(:handle_record_error).once
    end

    it 'passes NASA ID to record_result' do
      service.process_backlog

      expect(service).to have_received(:record_result).with(
        hash_including(identifier: '20230015324')
      )
    end

    it 'respects API rate limiting' do
      service.process_backlog

      expect(service).to have_received(:sleep).with(3).once
    end
  end

  describe '#metadata_json_for_nasa_id' do
    it 'reads and parses metadata.json correctly' do
      metadata = service.send(:metadata_json_for_nasa_id, '20230015324')

      expect(metadata['id']).to eq(20230015324)
      expect(metadata['title']).to eq('Using Regionalized Air Quality Model Performance')
    end

    it 'returns nil if metadata.json does not exist' do
      metadata = service.send(:metadata_json_for_nasa_id, 'nonexistent')

      expect(metadata).to be_nil
    end

    it 'raises error if JSON parsing fails' do
      File.write(File.join(data_dir, '20230015324', 'metadata.json'), 'invalid json')

      expect {
        service.send(:metadata_json_for_nasa_id, '20230015324')
      }.to raise_error(JSON::ParserError)
    end
  end

  describe '#remaining_ids_from_data_dir' do
    before do
      # Add another directory
      FileUtils.mkdir_p(File.join(data_dir, '20230015325'))
    end

    it 'returns all directory names' do
      ids = service.send(:remaining_ids_from_data_dir)

      expect(ids).to contain_exactly('20230015324', '20230015325')
    end

    it 'excludes hidden files' do
      FileUtils.touch(File.join(data_dir, '.DS_Store'))

      ids = service.send(:remaining_ids_from_data_dir)

      expect(ids).not_to include('.DS_Store')
    end

    it 'excludes IDs in seen list' do
      service.instance_variable_get(:@seen_identifier_list).add('20230015324')

      ids = service.send(:remaining_ids_from_data_dir)

      expect(ids).not_to include('20230015324')
      expect(ids).to include('20230015325')
    end
  end

  describe '#new_article' do
    let(:attr_builder) { instance_double(Tasks::NASAIngest::Backlog::Utilities::AttributeBuilders::NASAAttributeBuilder) }
    let(:article) { FactoryBot.build(:article) }

    before do
      allow(Article).to receive(:new).and_return(article)
      allow(attr_builder).to receive(:populate_article_metadata)
      allow(article).to receive(:save!)
      allow(service).to receive(:sync_permissions_and_state!)
    end

    it 'populates article metadata using attribute builder' do
      service.send(:new_article, metadata: sample_metadata, attr_builder: attr_builder, config: config, nasa_id: '20230015324')

      expect(attr_builder).to have_received(:populate_article_metadata).with(article)
    end

    it 'syncs permissions and state' do
      service.send(:new_article, metadata: sample_metadata, attr_builder: attr_builder, config: config, nasa_id: '20230015324')

      expect(service).to have_received(:sync_permissions_and_state!).with(
        work_id: article.id,
        depositor_uid: depositor.uid,
        admin_set: kind_of(AdminSet)
      )
    end
  end

  describe 'error handling' do
    before do
      allow(WorkUtilsHelper).to receive(:fetch_work_data_by_alternate_identifier).and_return(nil)
      allow(service).to receive(:record_result)
      allow(service).to receive(:flush_buffer_if_needed)
      allow(service).to receive(:flush_buffer_to_file)
      allow(service).to receive(:sleep)
    end

    it 'logs error with NASA ID and filename' do
      allow(Tasks::NASAIngest::Backlog::Utilities::AttributeBuilders::NASAAttributeBuilder)
        .to receive(:new).and_raise(StandardError.new('Builder error'))
      allow(service).to receive(:handle_record_error)

      service.process_backlog

      expect(service).to have_received(:handle_record_error).with(
        '20230015324',
        instance_of(StandardError),
        filename: '20230015324.pdf'
      )
    end
  end
end
