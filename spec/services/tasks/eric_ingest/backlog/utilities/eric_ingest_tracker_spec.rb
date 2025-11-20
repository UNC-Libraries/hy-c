# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::EricIngest::Backlog::Utilities::EricIngestTracker, type: :service do
  let(:config) do
    {
      'output_dir' => '/tmp/eric_output',
    }
  end

  let(:tracker) { described_class.new(config) }

  before do
    # prevent any real file writing
    allow(File).to receive(:exist?).and_return(false)
    allow(File).to receive(:write)
  end

  describe '#initialize_new!' do
    before do
      # base state like after initialize
      tracker.instance_variable_set(:@data, { 'progress' => {} })
      tracker.initialize_new!(config)
    end

    it 'calls super and merges expected ERIC-specific progress keys' do
      progress = tracker.instance_variable_get(:@data)['progress']

      expect(progress.keys).to include('metadata_ingest', 'attach_files_to_works', 'send_summary_email')
      expect(progress['metadata_ingest']['completed']).to be(false)
      expect(progress['attach_files_to_works']['completed']).to be(false)
      expect(progress['send_summary_email']['completed']).to be(false)
    end
  end
end
