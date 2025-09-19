# frozen_string_literal: true
require 'rails_helper'

RSpec.describe PubmedIngestRemediationService do
  let(:report_path) { Rails.root.join('tmp', 'test_duplicate_report.jsonl') }
  let(:start_date_obj) { Date.parse('2025-09-01') }
  let(:end_date_obj) { Date.parse('2025-09-30') }

  describe '.find_and_resolve_duplicates!' do
    let(:article1) { double(Article, id: 'A1', deposited_at: Time.parse('2025-09-01'), identifier: ['DOI: https://dx.doi.org/10.123/abc']) }
    let(:article2) { double(Article, id: 'A2', deposited_at: Time.parse('2025-09-02'), identifier: ['DOI: https://dx.doi.org/10.123/abc']) }
    let(:article3) { double(Article, id: 'A3', deposited_at: Time.parse('2025-09-03'), identifier: ['DOI: https://doi.org/10.123/abc']) }

    before do
      allow(ActiveFedora::SolrService).to receive(:get).and_wrap_original do |m, query, opts|
        if query.include?('system_create_dtsi')
          {
            'response' => {
              'docs' => [
                { 'id' => 'A1', 'identifier_tesim' => ['DOI: https://dx.doi.org/10.123/abc'], 'system_create_dtsi' => '2025-09-01T00:00:00Z' },
                { 'id' => 'A2', 'identifier_tesim' => ['DOI: https://dx.doi.org/10.123/abc'], 'system_create_dtsi' => '2025-09-02T00:00:00Z' }
              ]
            }
          }
        elsif query.include?('10.123/abc')
          {
            'response' => {
              'docs' => [
                { 'id' => 'A1', 'system_create_dtsi' => '2025-09-01T00:00:00Z' },
                { 'id' => 'A2', 'system_create_dtsi' => '2025-09-02T00:00:00Z' },
                { 'id' => 'A3', 'system_create_dtsi' => '2025-09-03T00:00:00Z' }
              ]
            }
          }
        else
          { 'response' => { 'docs' => [] } }
        end
      end

      allow(JsonFileUtilsHelper).to receive(:write_jsonl)
      allow(JsonFileUtilsHelper).to receive(:read_jsonl).and_return([
        { doi: '10.123/abc', work_ids: ['A1', 'A2', 'A3'], timestamps: ['2025-09-01T00:00:00Z', '2025-09-02T00:00:00Z', '2025-09-03T00:00:00Z'] }
      ])
    end

    it 'writes a duplicate report' do
      # described_class.find_and_resolve_duplicates!(since: Date.today, report_filepath: report_path, dry_run: true)
      described_class.find_and_resolve_duplicates!(start_date: start_date_obj, end_date: end_date_obj, report_filepath: report_path, dry_run: true)
      expect(JsonFileUtilsHelper).to have_received(:write_jsonl)
    end

    it 'normalizes both dx.doi.org and doi.org formats to the same key' do
      expect(JsonFileUtilsHelper).to receive(:write_jsonl) do |payload, *_|
        # Grab the DOI keys that were written and ensure it's normalized
        doi_keys = payload.map { |h| h[:doi] }
        expect(doi_keys).to include('10.123/abc')
        expect(doi_keys).not_to include('https://dx.doi.org/10.123/abc')
        expect(doi_keys).not_to include('https://doi.org/10.123/abc')
      end
      # described_class.find_and_resolve_duplicates!(since: Date.today, report_filepath: report_path, dry_run: true)
      described_class.find_and_resolve_duplicates!(start_date: start_date_obj, end_date: end_date_obj, report_filepath: report_path, dry_run: true)
    end

    context 'dry run' do
      it 'does not destroy any works' do
        allow(Article).to receive(:find).and_return(article1, article2)
        expect(article2).not_to receive(:destroy)
        # described_class.find_and_resolve_duplicates!(since: Date.today, report_filepath: report_path, dry_run: true)
        described_class.find_and_resolve_duplicates!(start_date: start_date_obj, end_date: end_date_obj, report_filepath: report_path, dry_run: true)
      end
    end

    context 'actual run' do
      it 'destroys all but the oldest duplicate' do
        a1 = instance_double(Article, id: 'A1')
        a2 = instance_double(Article, id: 'A2')
        a3 = instance_double(Article, id: 'A3')

        allow(Article).to receive(:find).with('A1').and_return(a1)
        allow(Article).to receive(:find).with('A2').and_return(a2)
        allow(Article).to receive(:find).with('A3').and_return(a3)

        expect(a2).to receive(:destroy)
        expect(a3).to receive(:destroy)

        described_class.find_and_resolve_duplicates!(
          start_date: start_date_obj,
          end_date: end_date_obj,
          report_filepath: report_path,
          dry_run: false
        )
      end
    end
  end

  describe '.find_and_update_empty_abstracts' do
    let(:article_with_empty_abstract) do
      double(
        Article,
        id: 'A3',
        deposited_at: Time.parse('2025-09-05'),
        abstract: [''],
      )
    end

    before do
      allow(ActiveFedora::SolrService).to receive(:get).and_return({
        'response' => { 'docs' => [{ 'id' => 'A3' }] }
      })

      allow(Article).to receive(:find).with('A3').and_return(article_with_empty_abstract)
      allow(article_with_empty_abstract).to receive(:update!)
      allow(article_with_empty_abstract).to receive(:update_index)
      allow(JsonFileUtilsHelper).to receive(:write_json)
    end

    context 'dry run' do
      it 'does not update the work' do
        described_class.find_and_update_empty_abstracts(
          start_date: start_date_obj,
          end_date: end_date_obj,
          report_filepath: report_path,
          dry_run: true
        )
        expect(article_with_empty_abstract).not_to have_received(:update!)
      end
    end

    context 'actual run' do
      it 'updates the abstract and reindexes the work' do
        described_class.find_and_update_empty_abstracts(
          start_date: start_date_obj,
          end_date: end_date_obj,
          report_filepath: report_path,
          dry_run: false
        )
        expect(article_with_empty_abstract).to have_received(:update!).with(abstract: ['N/A'])
        expect(article_with_empty_abstract).to have_received(:update_index)
        expect(JsonFileUtilsHelper).to have_received(:write_json)
      end
    end
  end
end
