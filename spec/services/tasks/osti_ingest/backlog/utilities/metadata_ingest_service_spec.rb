# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::OstiIngest::Backlog::Utilities::MetadataIngestService do
  let(:admin_set) { FactoryBot.create(:admin_set) }
  let(:depositor) { FactoryBot.create(:user) }
  let(:config) do
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
  let(:tracker) { Tasks::OstiIngest::Backlog::Utilities::OstiIngestTracker.new(config) }
  let(:metadata_ingest_result_path) { '/tmp/osti_metadata_ingest_results.jsonl' }

  subject(:service) do
    described_class.new(
      config: config,
      tracker: tracker,
      md_ingest_results_path: metadata_ingest_result_path
      )
  end

  describe '#initialize' do
    it 'sets instance variables correctly' do
      expect(service.instance_variable_get(:@config)).to eq(config)
      expect(service.instance_variable_get(:@tracker)).to eq(tracker)
      expect(service.instance_variable_get(:@md_ingest_results_path)).to eq(metadata_ingest_result_path)
      expect(service.instance_variable_get(:@seen_identifier_list)).to be_a(Set)
      expect(service.instance_variable_get(:@write_buffer)).to eq([])
      expect(service.instance_variable_get(:@flush_threshold)).to eq(100)
    end
  end

  describe '#identifier_key_name' do
    it 'returns the correct identifier key name' do
      expect(service.identifier_key_name).to eq('osti_id')
    end
  end

  describe '#process_backlog' do
    before do
      allow(service).to receive(:remaining_ids_from_directory).and_return(['123456', '654321'])
      allow(service).to receive(:fetch_metadata_for_osti_id).with('123456').and_return({ 'title' => 'Test Title 1' })
      allow(service).to receive(:fetch_metadata_for_osti_id).with('654321').and_return({ 'title' => 'Test Title 2' })
      allow(Tasks::OstiIngest::Backlog::Utilities::AttributeBuilders::OstiAttributeBuilder).to receive(:new).and_call_original
      allow(service).to receive(:new_article).and_return(FactoryBot.build(:article))
      allow(Dir).to receive(:glob).and_return([])
      allow(service).to receive(:sleep)
      allow(service).to receive(:record_result)
      allow(service).to receive(:flush_buffer_if_needed)
      allow(service).to receive(:flush_buffer_to_file)
      allow(Rails.logger).to receive(:info)
      allow(LogUtilsHelper).to receive(:double_log)
    end

    it 'processes remaining OSTI IDs and records results' do
      service.process_backlog

      expect(service).to have_received(:fetch_metadata_for_osti_id).with('123456')
      expect(service).to have_received(:fetch_metadata_for_osti_id).with('654321')
      expect(Tasks::OstiIngest::Backlog::Utilities::AttributeBuilders::OstiAttributeBuilder).to have_received(:new).twice
      expect(service).to have_received(:new_article).twice
      expect(service).to have_received(:record_result).twice
      expect(service).to have_received(:flush_buffer_if_needed).at_least(:twice)
    end

    it 'skips already seen OSTI IDs' do
      service.instance_variable_get(:@seen_identifier_list).add('123456')

      service.process_backlog

      expect(service).to have_received(:fetch_metadata_for_osti_id).once.with('654321')
      expect(service).to have_received(:record_result).once
    end

    it 'skips existing works with the same OSTI ID' do
      existing_work = FactoryBot.create(:article)
      allow(WorkUtilsHelper).to receive(:fetch_work_data_by_alternate_identifier)
        .with('123456', admin_set_title: config['admin_set_title'])
        .and_return({ work_id: existing_work.id.to_s })
      allow(WorkUtilsHelper).to receive(:fetch_work_data_by_alternate_identifier)
        .with('654321', admin_set_title: config['admin_set_title'])
        .and_return(nil)

      service.process_backlog

      expect(service).to have_received(:record_result).at_least(:once)
      expect(service).to have_received(:fetch_metadata_for_osti_id).once.with('654321')
    end
  end
end
