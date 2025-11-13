# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::IngestHelperUtils::MetadataIngestHelper do
  # Create a test class that includes the module
  let(:test_class) do
    Class.new do
      include Tasks::IngestHelperUtils::MetadataIngestHelper

      attr_accessor :seen_identifier_list, :write_buffer, :flush_threshold, 
                    :md_ingest_results_path, :config

      def initialize
        @seen_identifier_list = Set.new
        @write_buffer = []
        @flush_threshold = 3
        @md_ingest_results_path = '/tmp/test_results.jsonl'
        @config = { 'admin_set_title' => 'Test Admin Set' }
      end

      def identifier_key_name
        'eric_id'  
      end
    end
  end

  let(:instance) { test_class.new }
  let(:article) { FactoryBot.build(:article) }

  before do
    # Clean up test file
    File.delete(instance.md_ingest_results_path) if File.exist?(instance.md_ingest_results_path)
    
    # Stub Rails logger
    allow(Rails).to receive(:logger).and_return(double(info: nil, error: nil))
    allow(LogUtilsHelper).to receive(:double_log)
  end

  after do
    File.delete(instance.md_ingest_results_path) if File.exist?(instance.md_ingest_results_path)
  end

  describe '#record_result' do
    it 'adds identifier to seen list' do
      instance.record_result(category: :success, identifier: '10.1234/test', article: nil)
      expect(instance.seen_identifier_list).to include('10.1234/test')
    end

    it 'adds entry to write buffer' do
      instance.record_result(category: :success, identifier: '10.1234/test', article: nil, filename: 'test.pdf')
      expect(instance.write_buffer.size).to eq(1)
      expect(instance.write_buffer.first[:ids]).to eq({ 'eric_id' => '10.1234/test', 'work_id' => nil })
    end

    it 'includes article work_id when provided' do
      instance.record_result(category: :success, identifier: '10.1234/test', article: article)
      expect(instance.write_buffer.first[:ids]['work_id']).to eq(article.id)
    end

    it 'includes message when provided' do
      instance.record_result(category: :failed, identifier: '10.1234/test', message: 'Error occurred')
      expect(instance.write_buffer.first[:message]).to eq('Error occurred')
    end

    it 'flushes buffer when threshold reached' do
      expect(instance).to receive(:flush_buffer_to_file)
      3.times { |i| instance.record_result(category: :success, identifier: "10.1234/test#{i}") }
    end
  end

  describe '#extract_alternate_ids_from_article' do
    it 'returns nil for negative categories' do
      result = instance.extract_alternate_ids_from_article(article, :failed)
      expect(result).to be_nil
    end

    it 'returns nil when article is nil' do
      result = instance.extract_alternate_ids_from_article(nil, :success)
      expect(result).to be_nil
    end

    it 'extracts pmid and pmcid when available' do
      work_hash = { pmid: '12345', pmcid: 'PMC67890', eric_id: '10.1234/test' }
      allow(WorkUtilsHelper).to receive(:fetch_work_data_by_id).and_return(work_hash)
      
      result = instance.extract_alternate_ids_from_article(article, :success)
      expect(result).to eq({ 'pmid' => '12345', 'pmcid' => 'PMC67890' })
    end
  end

  describe '#flush_buffer_to_file' do
    it 'writes entries to file and clears buffer' do
      instance.record_result(category: :success, identifier: '10.1234/test')
      instance.flush_buffer_to_file
      
      expect(instance.write_buffer).to be_empty
      expect(File.exist?(instance.md_ingest_results_path)).to be true
    end

    it 'writes valid JSON lines' do
      instance.record_result(category: :success, identifier: '10.1234/test')
      instance.flush_buffer_to_file
      
      lines = File.readlines(instance.md_ingest_results_path)
      expect { JSON.parse(lines.first) }.not_to raise_error
    end
  end

  describe '#load_last_results' do
    it 'returns empty set when file does not exist' do
      result = instance.load_last_results('eric_id')
      expect(result).to eq(Set.new)
    end

    it 'loads identifiers from existing file' do
      File.open(instance.md_ingest_results_path, 'w') do |f|
        f.puts({ ids: { 'eric_id' => '10.1234/test1' } }.to_json)
        f.puts({ ids: { 'eric_id' => '10.1234/test2' } }.to_json)
      end
      
      result = instance.load_last_results('eric_id')
      expect(result).to eq(Set.new(['10.1234/test1', '10.1234/test2']))
    end
  end

  describe '#skip_existing_work' do
    let(:match) { { work_type: 'Article', work_id: article.id } }

    before do
      allow(WorkUtilsHelper).to receive(:fetch_model_instance).and_return(article)
    end

    it 'logs and records skipped work' do
      expect(Rails.logger).to receive(:info).with(/Skipping work/)
      instance.skip_existing_work('10.1234/test', match)
      
      expect(instance.write_buffer.size).to eq(1)
      expect(instance.write_buffer.first[:category]).to eq(:skipped)
    end
  end

  describe '#handle_record_error' do
    let(:error) { StandardError.new('Test error') }

    it 'handles string identifier' do
      expect(Rails.logger).to receive(:error).at_least(:once)
      instance.handle_record_error('10.1234/test', error, filename: 'test.pdf')
      
      expect(instance.write_buffer.first[:category]).to eq(:failed)
      expect(instance.write_buffer.first[:message]).to eq('Test error')
    end

    it 'handles hash with identifier key' do
      record = { 'eric_id' => '10.1234/test' }
      instance.handle_record_error(record, error)
      
      expect(instance.write_buffer.first[:ids]['eric_id']).to eq('10.1234/test')
    end
  end

  describe '#identifier_key_name' do
    it 'is implemented by including class' do
      expect(instance.identifier_key_name).to eq('eric_id')
    end

    it 'raises error if not implemented' do
      test_class_without_implementation = Class.new do
        include Tasks::IngestHelperUtils::MetadataIngestHelper
      end
      
      expect { test_class_without_implementation.new.identifier_key_name }
        .to raise_error(NotImplementedError)
    end
  end
end