# frozen_string_literal: true
require 'rails_helper'
RSpec.describe Tasks::IngestHelperUtils::ReportingHelper, type: :module do
describe '#format_results_for_reporting' do
    let(:raw_results) do
      [
        {
          category: 'successfully_ingested_and_attached',
          work_id: 'work_123',
          message: 'Successfully ingested and attached',
          ids: { pmid: '234567', pmcid: 'PMC890123', doi: '10.1000/example2' },
          file_name: 'NONE'
        },
        {
          category: 'successfully_ingested_metadata_only',
          work_id: 'work_456',
          message: 'Successfully ingested',
          ids: { pmid: '345678', pmcid: 'PMC901234', doi: '10.1000/example' },
          file_name: 'NONE'
        },
        {
          category: 'successfully_attached',
          work_id: 'work_789',
          message: 'Successfully attached',
          ids: { pmid: '567890', pmcid: 'PMC123456', doi: '10.1000/example3' },
          file_name: 'PMC123456_001.pdf'
        },
        {
          category: 'skipped',
          work_id: nil,
          message: 'Already exists',
          ids: { pmid: '456789' },
          file_name: 'NONE'
        },
        {
          category: 'skipped_file_attachment',
          work_id: 'work_101',
          message: 'No files to attach',
          ids: { pmid: '678901', pmcid: 'PMC234567', doi: '10.1000/example4' },
          file_name: 'NONE'
        },
        {
          category: 'failed',
          work_id: nil,
          message: 'Ingest failed',
          ids: { pmid: '123456' },
          file_name: 'NONE'
        },
        {
          category: 'invalid_category',
          message: 'Should be ignored',
          ids: { pmid: '999999' },
          file_name: 'NONE'
        },
           {
          category: 'skipped_non_unc_affiliation',
          work_id: nil,
          message: 'N/A',
          ids: { pmid: '456789' },
          file_name: 'NONE'
        }
      ]
    end

    let(:tracker) { {
        'restart_time' => '2024-01-02T00:00:00Z',
        'start_time' => '2024-01-01T00:00:00Z'
    } }

    before do
        %w[work_123 work_456 work_789 work_101].each do |work_id|
            allow(WorkUtilsHelper).to receive(:generate_cdr_url_for_work_id).with(work_id).and_return("http://example.com/#{work_id}")
        end
    end

    it 'formats valid categories correctly' do
      results = Tasks::IngestHelperUtils::ReportingHelper.send(:format_results_for_reporting, raw_results_array: raw_results, tracker: tracker)
      expect(results[:successfully_ingested_and_attached].size).to eq(1)
      expect(results[:successfully_ingested_metadata_only].size).to eq(1)
      expect(results[:successfully_attached].size).to eq(1)
      expect(results[:skipped].size).to eq(1)
      expect(results[:skipped_file_attachment].size).to eq(1)
      expect(results[:skipped_non_unc_affiliation].size).to eq(1)
      expect(results[:failed].size).to eq(1)
    end

    it 'ignores invalid categories' do
      results = Tasks::IngestHelperUtils::ReportingHelper.send(:format_results_for_reporting, raw_results_array: raw_results, tracker: tracker)
      expect(results).not_to have_key(:invalid_category)
    end

    it 'merges IDs into main entry and transforms field names' do
      results = Tasks::IngestHelperUtils::ReportingHelper.send(:format_results_for_reporting, raw_results_array: raw_results, tracker: tracker)
      ingested_entry = results[:successfully_ingested_metadata_only].first

      expect(ingested_entry[:pmid]).to eq('345678')
      expect(ingested_entry[:pmcid]).to eq('PMC901234')
      expect(ingested_entry[:doi]).to eq('10.1000/example')
      expect(ingested_entry[:work_id]).to eq('work_456')
      expect(ingested_entry[:message]).to eq('Successfully ingested')
      expect(ingested_entry[:file_name]).to eq('NONE')
      expect(ingested_entry[:cdr_url]).to eq('http://example.com/work_456')
    end

    it 'handles entries without work_id correctly' do
      results = Tasks::IngestHelperUtils::ReportingHelper.send(:format_results_for_reporting, raw_results_array: raw_results, tracker: tracker)
      skipped_entry = results[:skipped].first

      expect(skipped_entry[:pmid]).to eq('456789')
      expect(skipped_entry[:work_id]).to be_nil
      expect(skipped_entry).not_to have_key('cdr_url')
    end
  end
end