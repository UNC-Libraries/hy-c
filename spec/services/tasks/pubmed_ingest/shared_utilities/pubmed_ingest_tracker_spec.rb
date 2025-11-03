# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::PubmedIngest::SharedUtilities::PubmedIngestTracker, type: :service do
  let(:config) { {
    'depositor_onyen' => 'admin',
    'output_dir' => '/test/dir' }
  }

  subject(:tracker) { described_class.new(config) }

  before do
    # Stub super to set @data baseline
    allow_any_instance_of(Tasks::IngestHelperUtils::BaseIngestTracker)
      .to receive(:initialize_new!)
      .and_wrap_original do |m, *args|
        tracker.instance_variable_set(:@data, { 'progress' => {} })
      end
  end

  describe '#initialize_new!' do
    it 'initializes all progress sections with expected structure' do
      tracker.initialize_new!(config)
      data = tracker.instance_variable_get(:@data)

      progress = data['progress']
      expect(progress).to include(
        'retrieve_ids_within_date_range',
        'stream_and_write_alternate_ids',
        'adjust_id_lists',
        'metadata_ingest',
        'attach_files_to_works',
        'send_summary_email'
      )

      # Verify nested keys for retrieve_ids_within_date_range
      expect(progress['retrieve_ids_within_date_range']).to eq(
        'pubmed' => { 'cursor' => 0, 'completed' => false },
        'pmc' => { 'cursor' => 0, 'completed' => false }
      )

      # Verify adjust_id_lists structure
      expect(progress['adjust_id_lists']).to eq(
        'completed' => false,
        'pubmed' => { 'original_size' => 0, 'adjusted_size' => 0 },
        'pmc' => { 'original_size' => 0, 'adjusted_size' => 0 }
      )

      expect(progress['attach_files_to_works']).to eq('completed' => false)
      expect(progress['send_summary_email']).to eq('completed' => false)
    end
  end
end
