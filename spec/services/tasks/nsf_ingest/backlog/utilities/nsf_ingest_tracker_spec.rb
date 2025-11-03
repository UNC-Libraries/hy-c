# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::NSFIngest::Backlog::Utilities::NsfIngestTracker, type: :service do
  let(:config) do
    {
      'output_dir' => '/tmp/nsf_output',
      'file_info_csv_path' => '/tmp/nsf_file_info.csv'
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

    it 'calls super and merges expected NSF-specific progress keys' do
      progress = tracker.instance_variable_get(:@data)['progress']

      expect(progress.keys).to include('metadata_ingest', 'attach_files_to_works', 'send_summary_email')
      expect(progress['metadata_ingest']['completed']).to be(false)
      expect(progress['attach_files_to_works']['completed']).to be(false)
      expect(progress['send_summary_email']['completed']).to be(false)
    end

    it 'stores the file_info_csv_path in tracker data' do
      expect(tracker.instance_variable_get(:@data)['file_info_csv_path'])
        .to eq('/tmp/nsf_file_info.csv')
    end
  end
end
