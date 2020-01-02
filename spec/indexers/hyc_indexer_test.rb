require 'rails_helper'

RSpec.describe HycIndexer, type: :indexer do
  let(:work) { General.new(title: ['New General Work']) }
  let(:service) { described_class.new(work) }
  subject(:solr_document) { service.generate_solr_document }

  describe 'with date issued' do
    context 'as full date' do
      it "indexes id and label" do
        work.date_issued = ['2018-10-01']

        expect(solr_document.fetch('date_issued_tesim')).to eq ['October 1, 2018']
        expect(solr_document.fetch('date_issued_edtf_tesim')).to eq ['2018-10-01']
        expect(solr_document.fetch('date_issued_isim')).to eq [2018]
        expect(solr_document.fetch('date_issued_sort_ssi')).to eq '2018-10-01'
        expect(solr_document.fetch('title_sort_ssi')).to eq 'new general work'
      end
    end

    context 'as date range' do
      it "indexes id and label" do
        work.date_issued = ['2016 to 2019']

        expect(solr_document.fetch('date_issued_tesim')).to eq ['2016 to 2019']
        expect(solr_document.fetch('date_issued_edtf_tesim')).to eq ['2016 to 2019']
        expect(solr_document.fetch('date_issued_isim')).to eq [2016, 2017, 2018, 2019]
        expect(solr_document.fetch('date_issued_sort_ssi')).to eq '2016 to 2019'
        expect(solr_document.fetch('title_sort_ssi')).to eq 'new general work'
      end
    end

    context 'as decade' do
      it "indexes id and label" do
        work.date_issued = ['2010s']

        expect(solr_document.fetch('date_issued_tesim')).to eq ['2010s']
        expect(solr_document.fetch('date_issued_edtf_tesim')).to eq ['2010s']
        expect(solr_document.fetch('date_issued_isim')).to match_array((2010..2019).to_a)
        expect(solr_document.fetch('date_issued_sort_ssi')).to eq '2010s'
        expect(solr_document.fetch('title_sort_ssi')).to eq 'new general work'
      end
    end

    context 'as century' do
      it "indexes id and label" do
        work.date_issued = ['2000s']

        expect(solr_document.fetch('date_issued_tesim')).to eq ['2000s']
        expect(solr_document.fetch('date_issued_edtf_tesim')).to eq ['2000s']
        expect(solr_document.fetch('date_issued_isim')).to match_array((2000..2099).to_a)
        expect(solr_document.fetch('date_issued_sort_ssi')).to eq '2000s'
        expect(solr_document.fetch('title_sort_ssi')).to eq 'new general work'
      end
    end
  end

  describe 'without date issued' do
    before do
      work.date_issued = nil
    end

    it "indexes id and label" do
      expect(solr_document).to_not have_key('date_issued_tesim')
      expect(solr_document).to_not have_key('date_issued_edtf_tesim')
      expect(solr_document).to_not have_key('date_issued_isim')
      expect(solr_document).to_not have_key('date_issued_sort_ssi')
      expect(solr_document.fetch('title_sort_ssi')).to eq 'new general work'
    end
  end
end
