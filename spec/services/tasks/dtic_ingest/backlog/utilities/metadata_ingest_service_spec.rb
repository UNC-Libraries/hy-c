# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::DTICIngest::Backlog::Utilities::MetadataIngestService do
  let(:admin_set) { FactoryBot.create(:admin_set, title: ['DTIC Admin Set']) }
  let(:depositor) { FactoryBot.create(:user) }
  let(:csv_path) { '/tmp/dtic_metadata.csv' }
  let(:config) do
    {
      'input_csv_path' => csv_path,
      'output_dir' => '/tmp/dtic_output',
      'admin_set_title' => admin_set.title.first,
      'depositor_onyen' => depositor.uid
    }
  end
  let(:tracker) { Tasks::DTICIngest::Backlog::Utilities::DTICIngestTracker.new(config) }
  let(:md_ingest_results_path) { '/tmp/dtic_metadata_results.jsonl' }

  subject(:service) do
    described_class.new(
      config: config,
      tracker: tracker,
      md_ingest_results_path: md_ingest_results_path
    )
  end

  let(:csv_content) do
    <<~CSV
      filename,content_date,creation_date,content_text,title,url,author,subject
      AD1192590.pdf,"Oct 3, 2022",D:20221027120639-04'00',"Test content","Test Article Title",https://example.com/AD1192590.pdf,"Blackburn, Troy","Test abstract"
      AD1168868.pdf,"May 14, 2022",D:20220429123132-04'00',"More content","Another Title",https://example.com/AD1168868.pdf,"Smith, Jane;Doe, John",""
    CSV
  end

  before do
    allow(LogUtilsHelper).to receive(:double_log)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)

    # Create CSV file
    File.write(csv_path, csv_content)
  end

  after do
    File.delete(csv_path) if File.exist?(csv_path)
  end

  describe '#initialize' do
    it 'sets instance variables from config' do
      expect(service.instance_variable_get(:@config)).to eq(config)
      expect(service.instance_variable_get(:@input_csv_path)).to eq(csv_path)
      expect(service.instance_variable_get(:@output_dir)).to eq('/tmp/dtic_output')
    end

    it 'initializes empty seen identifier list' do
      expect(service.instance_variable_get(:@seen_identifier_list)).to be_a(Set)
    end
  end

  describe '#identifier_key_name' do
    it 'returns dtic_id' do
      expect(service.identifier_key_name).to eq('dtic_id')
    end
  end

  describe '#process_backlog' do
    let(:attr_builder) { instance_double(Tasks::DTICIngest::Backlog::Utilities::AttributeBuilders::DTICAttributeBuilder) }

    before do
      allow(WorkUtilsHelper).to receive(:fetch_work_data_by_alternate_identifier).and_return(nil)
      allow(Tasks::DTICIngest::Backlog::Utilities::AttributeBuilders::DTICAttributeBuilder).to receive(:new).and_return(attr_builder)
      allow(service).to receive(:new_article).and_return(FactoryBot.build(:article))
      allow(service).to receive(:record_result)
      allow(service).to receive(:flush_buffer_if_needed)
      allow(service).to receive(:flush_buffer_to_file)
    end

    it 'processes all records from CSV' do
      expect(service).to receive(:new_article).twice

      service.process_backlog

      expect(LogUtilsHelper).to have_received(:double_log).with(
        '[MetadataIngestService] Ingest complete. Processed 2 records.',
        :info,
        tag: 'MetadataIngestService'
      )
    end

    it 'skips IDs already in seen list' do
      service.instance_variable_get(:@seen_identifier_list).add('AD1192590')

      expect(service).to receive(:new_article).once

      service.process_backlog
    end

    it 'skips existing works with matching DTIC ID' do
      allow(WorkUtilsHelper).to receive(:fetch_work_data_by_alternate_identifier)
        .with('AD1192590', admin_set_title: admin_set.title.first)
        .and_return({ work_id: 'existing-123' })
      allow(service).to receive(:skip_existing_work)

      expect(service).to receive(:new_article).once

      service.process_backlog
    end

    it 'creates attribute builder for each record' do
      service.process_backlog

      expect(Tasks::DTICIngest::Backlog::Utilities::AttributeBuilders::DTICAttributeBuilder)
        .to have_received(:new).twice
    end

    it 'handles errors and continues processing' do
      allow(service).to receive(:new_article).and_raise(StandardError.new('Test error'))
      allow(service).to receive(:handle_record_error)

      service.process_backlog

      expect(service).to have_received(:handle_record_error).twice
    end

    it 'extracts DTIC ID from filename' do
      service.process_backlog

      expect(service).to have_received(:record_result).with(
        hash_including(identifier: 'AD1192590')
      )
      expect(service).to have_received(:record_result).with(
        hash_including(identifier: 'AD1168868')
      )
    end
  end

  describe 'CSV parsing' do
    let(:attr_builder) { instance_double(Tasks::DTICIngest::Backlog::Utilities::AttributeBuilders::DTICAttributeBuilder) }
    let(:article) { FactoryBot.build(:article) }

    before do
      allow(WorkUtilsHelper).to receive(:fetch_work_data_by_alternate_identifier).and_return(nil)
      allow(Tasks::DTICIngest::Backlog::Utilities::AttributeBuilders::DTICAttributeBuilder).to receive(:new).and_return(attr_builder)
      allow(Article).to receive(:new).and_return(article)
      allow(attr_builder).to receive(:populate_article_metadata)
      allow(article).to receive(:save!)
      allow(service).to receive(:sync_permissions_and_state!)
      allow(service).to receive(:record_result)
      allow(service).to receive(:flush_buffer_if_needed)
      allow(service).to receive(:flush_buffer_to_file)
    end

    it 'reads records from CSV with correct headers' do
      service.process_backlog

      expect(Tasks::DTICIngest::Backlog::Utilities::AttributeBuilders::DTICAttributeBuilder)
        .to have_received(:new).with(
          hash_including('filename' => 'AD1192590.pdf', 'title' => 'Test Article Title'),
          kind_of(AdminSet),
          depositor.uid
        )
    end

    it 'passes all CSV fields to attribute builder' do
      service.process_backlog

      expect(Tasks::DTICIngest::Backlog::Utilities::AttributeBuilders::DTICAttributeBuilder)
        .to have_received(:new).with(
          hash_including(
            'filename' => 'AD1192590.pdf',
            'content_date' => 'Oct 3, 2022',
            'subject' => 'Test abstract',
            'title' => 'Test Article Title',
            'author' => 'Blackburn, Troy'
          ),
          anything,
          anything
        )
    end

    it 'handles records with empty fields' do
      service.process_backlog

      expect(Tasks::DTICIngest::Backlog::Utilities::AttributeBuilders::DTICAttributeBuilder)
        .to have_received(:new).with(
          hash_including('filename' => 'AD1168868.pdf', 'subject' => ''),
          anything,
          anything
        )
    end
  end

  describe 'error handling' do
    before do
      allow(WorkUtilsHelper).to receive(:fetch_work_data_by_alternate_identifier).and_return(nil)
      allow(service).to receive(:record_result)
      allow(service).to receive(:flush_buffer_if_needed)
      allow(service).to receive(:flush_buffer_to_file)
    end

    it 'logs error with DTIC ID and filename' do
      allow(Tasks::DTICIngest::Backlog::Utilities::AttributeBuilders::DTICAttributeBuilder)
        .to receive(:new).and_raise(StandardError.new('Builder error'))
      allow(service).to receive(:handle_record_error)

      service.process_backlog

      expect(service).to have_received(:handle_record_error).with(
        'AD1192590',
        instance_of(StandardError),
        filename: 'AD1192590.pdf'
      )
    end
  end
end
