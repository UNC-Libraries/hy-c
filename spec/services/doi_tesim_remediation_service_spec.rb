# frozen_string_literal: true
# spec/services/doi_tesim_remediation_service_spec.rb
require 'rails_helper'

RSpec.describe DoiTesimRemediationService do
  subject(:service) { described_class.new }

  describe '#initialize' do
    it 'initializes counters to zero' do
      expect(service.updated_count).to eq(0)
      expect(service.error_count).to eq(0)
      expect(service.skipped_count).to eq(0)
    end
  end

  describe '#normalize_all_dois' do
    let(:docs) do
      [
        { 'id' => 'work1', 'doi_tesim' => ['10.1234/abc'] },
        { 'id' => 'work2', 'doi_tesim' => ['10.5678/def'] }
      ]
    end

    before do
      allow(service).to receive(:find_works_with_bare_dois).and_return(docs)
      allow(service).to receive(:normalize_work_doi)
      allow(service).to receive(:log_summary)
      allow(Rails.logger).to receive(:info)
    end

    it 'processes all documents' do
      service.normalize_all_dois

      expect(service).to have_received(:normalize_work_doi).with(docs[0])
      expect(service).to have_received(:normalize_work_doi).with(docs[1])
    end

    it 'logs the number of works found' do
      service.normalize_all_dois

      expect(Rails.logger).to have_received(:info).with('[DoiRemediation] Found 2 works with non-canonical DOI format')
    end

    it 'calls log_summary at the end' do
      service.normalize_all_dois

      expect(service).to have_received(:log_summary)
    end

    context 'when no works are found' do
      before do
        allow(service).to receive(:find_works_with_bare_dois).and_return([])
      end

      it 'returns early without processing' do
        service.normalize_all_dois

        expect(service).not_to have_received(:normalize_work_doi)
        expect(service).not_to have_received(:log_summary)
      end
    end
  end

  describe '#normalize_work_doi' do
    let(:work) { instance_double(Article, doi: '10.1234/abc', 'doi=': nil, save!: true) }
    let(:doc) { { 'id' => 'work123', 'doi_tesim' => ['10.1234/abc'] } }

    before do
      allow(ActiveFedora::Base).to receive(:find).with('work123').and_return(work)
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:error)
    end

    it 'normalizes and updates the work DOI' do
      service.normalize_work_doi(doc)

      expect(work).to have_received(:doi=).with('https://doi.org/10.1234/abc')
      expect(work).to have_received(:save!)
      expect(service.updated_count).to eq(1)
    end

    it 'logs successful update' do
      service.normalize_work_doi(doc)

      expect(Rails.logger).to have_received(:info).with('[DoiRemediation] Updated work123')
    end

    context 'when DOI is already normalized' do
      let(:doc) { { 'id' => 'work123', 'doi_tesim' => ['https://doi.org/10.1234/abc'] } }

      it 'skips the work without updating' do
        service.normalize_work_doi(doc)

        expect(work).not_to have_received(:doi=)
        expect(work).not_to have_received(:save!)
        expect(service.skipped_count).to eq(1)
        expect(service.updated_count).to eq(0)
      end
    end

    context 'when DOI is from dx.doi.org' do
      let(:doc) { { 'id' => 'work123', 'doi_tesim' => ['https://dx.doi.org/10.1234/abc'] } }

      it 'normalizes to doi.org' do
        service.normalize_work_doi(doc)

        expect(work).to have_received(:doi=).with('https://doi.org/10.1234/abc')
        expect(work).to have_received(:save!)
        expect(service.updated_count).to eq(1)
      end
    end

    context 'when doi_tesim is invalid' do
      let(:doc) { { 'id' => 'work123', 'doi_tesim' => ['invalid_doi'] } }

      it 'skips the work' do
        service.normalize_work_doi(doc)
        expect(service.skipped_count).to eq(1)
        expect(service.updated_count).to eq(0)
      end
    end

    context 'when DOI is bare' do
      let(:doc) { { 'id' => 'work123', 'doi_tesim' => ['10.1234/abc'] } }

      it 'normalizes to doi.org' do
        service.normalize_work_doi(doc)

        expect(work).to have_received(:doi=).with('https://doi.org/10.1234/abc')
        expect(work).to have_received(:save!)
        expect(service.updated_count).to eq(1)
      end
    end

    context 'when an error occurs' do
      before do
        allow(ActiveFedora::Base).to receive(:find).and_raise(StandardError.new('Test error'))
      end

      it 'increments error count' do
        service.normalize_work_doi(doc)

        expect(service.error_count).to eq(1)
        expect(service.updated_count).to eq(0)
      end

      it 'logs the error' do
        service.normalize_work_doi(doc)

        expect(Rails.logger).to have_received(:error).with('[DoiRemediation] Error processing work123: Test error')
      end
    end
  end

  describe '#find_works_with_bare_dois' do
    let(:solr_response) do
      {
        'response' => {
          'docs' => [
            { 'id' => 'work1', 'doi_tesim' => ['10.1234/abc'] },
            { 'id' => 'work2', 'doi_tesim' => ['10.5678/def'] }
          ]
        }
      }
    end

    before do
      allow(ActiveFedora::SolrService).to receive(:get).and_return(solr_response)
    end

    it 'queries Solr for works with bare DOIs' do
      service.send(:find_works_with_bare_dois)

      expect(ActiveFedora::SolrService).to have_received(:get).with(
        'doi_tesim:[* TO *] AND -doi_tesim:"https://*"',
        rows: 10000,
        fl: 'id,doi_tesim'
      )
    end

    it 'returns the documents from Solr response' do
      result = service.send(:find_works_with_bare_dois)

      expect(result).to eq(solr_response['response']['docs'])
    end
  end

  describe '#log_summary' do
    before do
      allow(Rails.logger).to receive(:info)
      service.instance_variable_set(:@updated_count, 10)
      service.instance_variable_set(:@error_count, 2)
      service.instance_variable_set(:@skipped_count, 5)
    end

    it 'logs summary with all counts' do
      service.send(:log_summary)

      expect(Rails.logger).to have_received(:info).with(
        '[DoiRemediation] Summary - Updated: 10, Errors: 2, Skipped: 5'
      )
    end
  end
end
