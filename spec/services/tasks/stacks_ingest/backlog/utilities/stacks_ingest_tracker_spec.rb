# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::StacksIngest::Backlog::Utilities::StacksIngestTracker do
  let(:config) do
    {
      'output_dir' => '/tmp/stacks_output',
      'input_csv_path' => '/tmp/stacks_data.csv'
    }
  end

  subject(:tracker) { described_class.new(config) }

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

    it 'calls super and adds expected Stacks-specific progress keys' do
      progress = tracker.instance_variable_get(:@data)['progress']

      expect(progress.keys).to include('metadata_ingest', 'attach_files_to_works', 'send_summary_email')
      expect(progress['metadata_ingest']['completed']).to be(false)
      expect(progress['attach_files_to_works']['completed']).to be(false)
      expect(progress['send_summary_email']['completed']).to be(false)
    end

    it 'adds input_csv_path to tracker data' do
      data = tracker.instance_variable_get(:@data)

      expect(data['input_csv_path']).to eq('/tmp/stacks_data.csv')
    end
  end
end
