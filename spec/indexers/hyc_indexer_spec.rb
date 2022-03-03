require 'rails_helper'

RSpec.describe HycIndexer, type: :indexer do
  let(:work) { General.new(title: ['New General Work']) }
  let(:service) { described_class.new(work) }
  subject(:solr_document) { service.generate_solr_document }

  describe 'indexing date issued' do
    context 'as full date' do
      it 'indexes id and label' do
        work.date_issued = ['2018-10-01']

        expect(solr_document.fetch('date_issued_tesim')).to eq ['October 1, 2018']
        expect(solr_document.fetch('date_issued_edtf_tesim')).to eq ['2018-10-01']
        expect(solr_document.fetch('date_issued_isim')).to eq [2018]
        expect(solr_document.fetch('date_issued_sort_ssi')).to eq '2018-10-01'
        expect(solr_document.fetch('title_sort_ssi')).to eq 'new general work'
      end
    end

    context 'as date range' do
      it 'indexes id and label' do
        work.date_issued = ['2016 to 2019']

        expect(solr_document.fetch('date_issued_tesim')).to eq ['2016 to 2019']
        expect(solr_document.fetch('date_issued_edtf_tesim')).to eq ['2016 to 2019']
        expect(solr_document.fetch('date_issued_isim')).to eq [2016, 2017, 2018, 2019]
        expect(solr_document.fetch('date_issued_sort_ssi')).to eq '2016 to 2019'
        expect(solr_document.fetch('title_sort_ssi')).to eq 'new general work'
      end
    end

    context 'as decade' do
      it 'indexes id and label' do
        work.date_issued = ['2010s']

        expect(solr_document.fetch('date_issued_tesim')).to eq ['2010s']
        expect(solr_document.fetch('date_issued_edtf_tesim')).to eq ['2010s']
        expect(solr_document.fetch('date_issued_isim')).to match_array((2010..2019).to_a)
        expect(solr_document.fetch('date_issued_sort_ssi')).to eq '2010s'
        expect(solr_document.fetch('title_sort_ssi')).to eq 'new general work'
      end
    end

    context 'as century' do
      it 'indexes id and label' do
        work.date_issued = ['2000s']

        expect(solr_document.fetch('date_issued_tesim')).to eq ['2000s']
        expect(solr_document.fetch('date_issued_edtf_tesim')).to eq ['2000s']
        expect(solr_document.fetch('date_issued_isim')).to match_array((2000..2099).to_a)
        expect(solr_document.fetch('date_issued_sort_ssi')).to eq '2000s'
        expect(solr_document.fetch('title_sort_ssi')).to eq 'new general work'
      end
    end
  end

  describe 'indexing without date issued' do
    before do
      work.date_issued = nil
    end

    it 'indexes id and label' do
      expect(solr_document).to_not have_key('date_issued_tesim')
      expect(solr_document).to_not have_key('date_issued_edtf_tesim')
      expect(solr_document).to_not have_key('date_issued_isim')
      expect(solr_document).to_not have_key('date_issued_sort_ssi')
      expect(solr_document.fetch('title_sort_ssi')).to eq 'new general work'
    end
  end

  describe 'indexing people objects' do
    let(:creator_array) { solr_doc.fetch('creator_display_tesim') }
    let(:expected_creator_array) do
      ['index:1||creator||ORCID: creator orcid||Affiliation: School of Medicine, Carolina Center for Genome Sciences||Other Affiliation: another affiliation',
       'index:2||creator2||ORCID: creator2 orcid||Affiliation: College of Arts and Sciences, Department of Chemistry||Other Affiliation: another affiliation']
    end

    let(:reviewer_array) { solr_doc.fetch('reviewer_display_tesim') }
    let(:expected_reviewer_array) do
      ['index:1||reviewer||ORCID: reviewer orcid||Affiliation: School of Medicine, Carolina Center for Genome Sciences||Other Affiliation: another affiliation',
       'index:2||reviewer2||ORCID: reviewer2 orcid||Affiliation: College of Arts and Sciences, Department of Chemistry||Other Affiliation: another affiliation']
    end
    let(:solr_doc) { described_class.new(work_with_people).generate_solr_document }

    context 'with a submitted index values' do
      let(:work_with_people) do
        General.new(title: ['New General Work with people'],
                    creators_attributes: { '0' => { name: 'creator',
                                                    orcid: 'creator orcid',
                                                    affiliation: 'Carolina Center for Genome Sciences',
                                                    other_affiliation: 'another affiliation',
                                                    index: 1 },
                                           '1' => { name: 'creator2',
                                                    orcid: 'creator2 orcid',
                                                    affiliation: 'Department of Chemistry',
                                                    other_affiliation: 'another affiliation',
                                                    index: 2 } },
                    reviewers_attributes: { '0' => { name: 'reviewer',
                                                     orcid: 'reviewer orcid',
                                                     affiliation: 'Carolina Center for Genome Sciences',
                                                     other_affiliation: 'another affiliation',
                                                     index: 1 },
                                            '1' => { name: 'reviewer2',
                                                     orcid: 'reviewer2 orcid',
                                                     affiliation: 'Department of Chemistry',
                                                     other_affiliation: 'another affiliation',
                                                     index: 2 } })
      end

      it 'retains existing index values' do
        expect(creator_array).to match_array(expected_creator_array)
        expect(reviewer_array).to match_array(expected_reviewer_array)
      end
    end

    context 'without a submitted index values' do
      let(:work_with_people) do
        General.new(title: ['New General Work with people'],
                    creators_attributes: { '0' => { name: 'creator',
                                                    orcid: 'creator orcid',
                                                    affiliation: 'Carolina Center for Genome Sciences',
                                                    other_affiliation: 'another affiliation' },
                                           '1' => { name: 'creator2',
                                                    orcid: 'creator2 orcid',
                                                    affiliation: 'Department of Chemistry',
                                                    other_affiliation: 'another affiliation' } },
                    reviewers_attributes: { '0' => { name: 'reviewer',
                                                     orcid: 'reviewer orcid',
                                                     affiliation: 'Carolina Center for Genome Sciences',
                                                     other_affiliation: 'another affiliation' },
                                            '1' => { name: 'reviewer2',
                                                     orcid: 'reviewer2 orcid',
                                                     affiliation: 'Department of Chemistry',
                                                     other_affiliation: 'another affiliation' } })
      end

      it 'adds missing index values' do
        pending('Actually adding missing index values')
        expect(creator_array).to match_array(expected_creator_array)
        expect(reviewer_array).to match_array(expected_reviewer_array)
      end
    end

    context 'with and without submitted index values' do
      let(:expected_creator_array) do
        ['index:2||creator||ORCID: creator orcid||Affiliation: School of Medicine, Carolina Center for Genome Sciences||Other Affiliation: another affiliation',
         'index:1||creator2||ORCID: creator2 orcid||Affiliation: College of Arts and Sciences, Department of Chemistry||Other Affiliation: another affiliation',
         'index:3||creator3||ORCID: creator3 orcid||Affiliation: Department of Chemistry||Other Affiliation: another affiliation']
      end

      let(:work_with_people) do
        General.new(title: ['New General Work with people'],
                    creators_attributes: { '0' => { name: 'creator',
                                                    orcid: 'creator orcid',
                                                    affiliation: 'Carolina Center for Genome Sciences',
                                                    other_affiliation: 'another affiliation',
                                                    index: 2 },
                                           '1' => { name: 'creator2',
                                                    orcid: 'creator2 orcid',
                                                    affiliation: 'Department of Chemistry',
                                                    other_affiliation: 'another affiliation',
                                                    index: 1 },
                                           '2' => { name: 'creator3',
                                                    orcid: 'creator3 orcid',
                                                    affiliation: 'Department of Chemistry',
                                                    other_affiliation: 'another affiliation' } },
                    reviewers_attributes: { '0' => { name: 'reviewer',
                                                     orcid: 'reviewer orcid',
                                                     affiliation: 'Carolina Center for Genome Sciences',
                                                     other_affiliation: 'another affiliation',
                                                     index: 1 },
                                            '1' => { name: 'reviewer2',
                                                     orcid: 'reviewer2 orcid',
                                                     affiliation: 'Department of Chemistry',
                                                     other_affiliation: 'another affiliation' } })
      end

      it 'retains existing index values and adds missing index values' do
        pending('Actually adding missing index values')
        expect(creator_array).to match_array(expected_creator_array)
        expect(reviewer_array).to match_array(expected_reviewer_array)
      end
    end
  end
end
