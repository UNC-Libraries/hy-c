# frozen_string_literal: true
require 'rails_helper'
require 'json'

RSpec.describe Tasks::PubmedIngest::SharedUtilities::PubmedReportingService do
  describe '#generate_report' do
    let(:fixture_path) do
      Rails.root.join('spec', 'fixtures', 'files', 'pubmed_ingest_test_fixture.json')
    end

    let(:ingest_output) do
      JSON.parse(File.read(fixture_path),  symbolize_names: true)
    end

    it 'returns a report hash with expected structure and values' do
      report = described_class.generate_report(ingest_output.symbolize_keys)
      expect(report[:headers][:depositor]).to eq(ingest_output[:depositor])
      expect(report[:formatted_time]).to eq(Time.parse(ingest_output[:time]).strftime('%B %d, %Y at %I:%M %p %Z'))
      expect(report[:file_retrieval_directory]).to eq(ingest_output[:file_retrieval_directory])
      expect(report[:headers][:depositor]).to eq(ingest_output[:depositor])
      expect(report[:headers][:total_unique_files]).to eq(ingest_output[:counts][:total_unique_files])
      expect(report[:records][:successfully_attached]).to eq(ingest_output[:successfully_attached])
      expect(report[:records][:successfully_ingested_metadata_only]).to eq(ingest_output[:successfully_ingested_metadata_only])
      expect(report[:records][:skipped]).to eq(ingest_output[:skipped])
      expect(report[:records][:failed]).to eq(ingest_output[:failed])
    end
  end
end
