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
end
