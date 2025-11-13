# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::EricIngest::Backlog::Utilities::MetadataIngestService do
  let(:admin_set) { FactoryBot.create(:admin_set) }
  let(:depositor) { FactoryBot.create(:user) }
  let(:config) do
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
  let(:tracker) { Tasks::EricIngest::Backlog::Utilities::EricIngestTracker.new(config) }
  let(:metadata_ingest_result_path) { '/tmp/eric_metadata_ingest_results.jsonl' }

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
      expect(service.identifier_key_name).to eq('eric_id')
    end
  end

  describe '#process_backlog' do
    before do
      allow(service).to receive(:remaining_ids_from_directory).and_return(['ED123456', 'ED654321'])
      allow(service).to receive(:fetch_metadata_for_eric_id).with('ED123456').and_return({ 'title' => 'Test Title 1' })
      allow(service).to receive(:fetch_metadata_for_eric_id).with('ED654321').and_return({ 'title' => 'Test Title 2' })
      allow(Tasks::EricIngest::Backlog::Utilities::AttributeBuilders::EricAttributeBuilder).to receive(:new).and_call_original
      allow(service).to receive(:new_article).and_return(FactoryBot.build(:article))
      allow(service).to receive(:record_result)
      allow(service).to receive(:flush_buffer_if_needed)
      allow(service).to receive(:flush_buffer_to_file)
      allow(Rails.logger).to receive(:info)
    end

    it 'processes remaining ERIC IDs and records results' do
      service.process_backlog

      expect(service).to have_received(:remaining_ids_from_directory).with(config['full_text_dir'])
      expect(service).to have_received(:fetch_metadata_for_eric_id).twice
      expect(Tasks::EricIngest::Backlog::Utilities::AttributeBuilders::EricAttributeBuilder).to have_received(:new).twice
      expect(service).to have_received(:new_article).twice
      expect(service).to have_received(:record_result).twice
      expect(service).to have_received(:flush_buffer_if_needed).at_least(:once)
      expect(Rails.logger).to have_received(:info).at_least(:once)
    end
  end
end
