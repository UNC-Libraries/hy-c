# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::PubmedIngest::SharedUtilities::PubmedReportingService, type: :service do
  describe '.generate_report' do
    let(:time_string) { '2025-02-15 10:30:00 -0500' }
    let(:ingest_output) do
      {
        time: time_string,
        file_retrieval_directory: '/tmp/pubmed_run_001',
        depositor: 'admin',
        successfully_ingested_and_attached: [{ 'id' => 1 }],
        successfully_ingested_metadata_only: [{ 'id' => 2 }],
        successfully_attached: [{ 'id' => 3 }],
        skipped_file_attachment: [{ 'id' => 4 }],
        skipped: [{ 'id' => 5 }],
        failed: [{ 'id' => 6 }],
        skipped_non_unc_affiliation: [{ 'id' => 7 }]
      }
    end

    it 'returns a structured report with formatted time and symbolized records' do
      report = described_class.generate_report(ingest_output)

      expect(report[:subject]).to include('Pubmed Ingest Report for')
      # Check that time is formatted correctly, but don't assert on timezone abbreviation
      expect(report[:formatted_time]).to match(/February 15, 2025 at 10:30 AM/)
      expect(report[:file_retrieval_directory]).to eq('/tmp/pubmed_run_001')
      expect(report[:headers][:depositor]).to eq('admin')

      # Records structure
      records = report[:records]
      expect(records.keys).to contain_exactly(
        :successfully_ingested_and_attached,
        :successfully_ingested_metadata_only,
        :successfully_attached,
        :skipped_file_attachment,
        :skipped,
        :failed,
        :skipped_non_unc_affiliation
      )

      # Each record array should contain symbolized keys
      expect(records[:successfully_ingested_and_attached].first).to eq({ id: 1 })
      expect(records[:failed].first).to eq({ id: 6 })
    end
  end
end