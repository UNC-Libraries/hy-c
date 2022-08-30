# frozen_string_literal: true
require 'rails_helper'

RSpec.describe HycIndexer, type: :indexer do
  let(:work) { General.new(title: ['New General Work']) }
  let(:service) { described_class.new(work) }
  subject(:solr_document) { service.generate_solr_document }

  before do
    # Configure QA to use fixtures
    qa_fixtures = { local_path: File.expand_path('spec/fixtures/authorities') }
    allow(Qa::Authorities::Local).to receive(:config).and_return(qa_fixtures)
  end

  describe 'indexing affiliations' do
    let(:solr_doc) { described_class.new(work_with_people).generate_solr_document }
    let(:solr_creator_array) { solr_doc.fetch('creator_display_tesim') }
    let(:solr_affiliation_array_tesim) { solr_doc.fetch('affiliation_label_tesim') }
    let(:solr_affiliation_array_sim) { solr_doc.fetch('affiliation_label_sim') }

    let(:solr_expected_creator_array) do
      ['index:1||creator||Affiliation: School of Medicine, Carolina Center for Genome Sciences',
       'index:2||creator2||Affiliation: College of Arts and Sciences, Department of Chemistry']
    end
    let(:fedora_creator_array) { work_with_people.creators.map(&:attributes) }
    let(:fedora_creator_hash_one) { fedora_creator_array.find { |hash| hash['index'] == [1] } }
    let(:fedora_creator_hash_two) { fedora_creator_array.find { |hash| hash['index'] == [2] } }

    context 'without any people objects' do
      let(:solr_doc) { described_class.new(work).generate_solr_document }

      it 'does not have creators for display in Solr' do
        expect(solr_doc.keys.include?('creator_display_tesim')).to be false
      end

      it 'does not have affiliations in Solr' do
        expect(solr_doc.keys.include?('affiliation_label_tesim')).to be false
        expect(solr_doc.keys.include?('affiliation_label_sim')).to be false
      end

      it 'does not have creators in Fedora' do
        expect(work.creators.empty?).to be true
      end
    end
    context 'using the regular departments vocabulary' do
      let(:work_with_people) do
        General.new(title: ['New General Work with people'],
                    creators_attributes: { '0' => { name: 'creator',
                                                    affiliation: 'Carolina Center for Genome Sciences',
                                                    index: 1 },
                                           '1' => { name: 'creator2',
                                                    affiliation: 'Department of Chemistry',
                                                    index: 2 } })
      end

      it 'maps the affiliation ids to labels in solr' do
        expect(solr_creator_array).to match_array(solr_expected_creator_array)
      end

      it 'maps the affiliations to the facet with the short_label' do
        expect(solr_affiliation_array_tesim).to match_array(['Test short Carolina Center for Genome Sciences', 'Test short Department of Chemistry'])
        expect(solr_affiliation_array_sim).to match_array(['Test short Carolina Center for Genome Sciences', 'Test short Department of Chemistry'])
      end

      it 'stores the id in Fedora' do
        expect(fedora_creator_hash_one['affiliation']).to eq(['Carolina Center for Genome Sciences'])
      end
    end

    context 'with a work ingested with ProQuest' do
      let(:solr_expected_creator_array) do
        ['index:1||creator||Affiliation: School of Medicine, Curriculum in Genetics and Molecular Biology',
         'index:2||creator2']
      end
      let(:work_with_people) do
        Dissertation.new(title: ['New General Work with people'],
                         creators_attributes: { '0' => { name: 'creator',
                                                         affiliation: ProquestDepartmentMappingsService.standard_department_name('Genetics &amp; Molecular Biology'),
                                                         index: 1 },
                                                '1' => { name: 'creator2',
                                                         affiliation: 'Some string parsed from xml that doesn\'t match anything',
                                                         index: 2 } })
      end

      it 'stores the affiliation id in Fedora' do
        expect(fedora_creator_hash_one['affiliation']).to eq(['Curriculum in Genetics and Molecular Biology'])
        expect(fedora_creator_hash_two['affiliation']).to eq(['Some string parsed from xml that doesn\'t match anything'])
      end

      it 'only indexes the controlled affiliation to Solr' do
        expect(solr_creator_array).to match_array(solr_expected_creator_array)
        expect(solr_affiliation_array_tesim).to match_array(['Test short Genetics and Molecular Biology'])
        expect(solr_affiliation_array_sim).to match_array(['Test short Genetics and Molecular Biology'])
      end
    end

    context 'with uncontrolled other_affiliation' do
      let(:work_with_people) do
        General.new(title: ['New General Work with people'],
                    creators_attributes: { '0' => { name: 'creator',
                                                    other_affiliation: 'Some Other Affiliation in Rotterdam',
                                                    index: 1 },
                                           '1' => { name: 'creator2',
                                                    other_affiliation: 'Some Other Affiliation in Spain',
                                                    index: 2 } })
      end
      let(:solr_expected_creator_array) do
        ['index:1||creator||Other Affiliation: Some Other Affiliation in Rotterdam',
         'index:2||creator2||Other Affiliation: Some Other Affiliation in Spain']
      end

      it 'stores the affiliation id in Fedora' do
        expect(fedora_creator_hash_one['other_affiliation']).to eq(['Some Other Affiliation in Rotterdam'])
        expect(fedora_creator_hash_two['other_affiliation']).to eq(['Some Other Affiliation in Spain'])
      end

      it 'indexes the other affiliation to Solr' do
        expect(solr_creator_array).to match_array(solr_expected_creator_array)
        expect(solr_doc.fetch('other_affiliation_label_tesim')).to match_array(['Some Other Affiliation in Rotterdam', 'Some Other Affiliation in Spain'])
        expect(solr_doc.key?('other_affiliation_label_sim')).to be false
      end
    end

    context 'without affiliation or other_affiliation' do
      let(:solr_expected_creator_array) do
        ['index:1||creator||ORCID: creator orcid',
         'index:2||creator2||ORCID: creator2 orcid']
      end
      let(:work_with_people) do
        General.new(title: ['New General Work with people'],
                    creators_attributes: { '0' => { name: 'creator',
                                                    orcid: 'creator orcid',
                                                    index: 1 },
                                           '1' => { name: 'creator2',
                                                    orcid: 'creator2 orcid',
                                                    index: 2 } })
      end

      it 'does not index an affiliation to solr' do
        expect(solr_creator_array).to match_array(solr_expected_creator_array)
        expect(solr_doc.keys.include?('affiliation_label_tesim')).to be false
        expect(solr_doc.keys.include?('affiliation_label_sim')).to be false
      end

      it 'does not include an affiliation value in fedora' do
        expect(fedora_creator_hash_one['affiliation'].to_a).to eq([])
        expect(fedora_creator_hash_one['other_affiliation'].to_a).to eq([])
      end
    end

    context 'with two of the same affiliation' do
      let(:solr_expected_creator_array) do
        ['index:1||creator||Affiliation: School of Medicine, Carolina Center for Genome Sciences||Other Affiliation: Matching string',
         'index:2||creator2||Affiliation: School of Medicine, Carolina Center for Genome Sciences||Other Affiliation: Matching string']
      end
      let(:work_with_people) do
        Dissertation.new(title: ['New General Work with people'],
                         creators_attributes: { '0' => { name: 'creator',
                                                         affiliation: 'Carolina Center for Genome Sciences',
                                                         other_affiliation: 'Matching string',
                                                         index: 1 },
                                                '1' => { name: 'creator2',
                                                         affiliation: 'Carolina Center for Genome Sciences',
                                                         other_affiliation: 'Matching string',
                                                         index: 2 } })
      end

      it 'indexes the creator affiliations separately' do
        expect(solr_creator_array).to match_array(solr_expected_creator_array)
      end

      it 'indexes the affiliations for faceting together' do
        expect(solr_affiliation_array_tesim).to match_array(['Test short Carolina Center for Genome Sciences'])
        expect(solr_affiliation_array_sim).to match_array(['Test short Carolina Center for Genome Sciences'])
      end
    end

    context 'with an empty string in affiliation' do
      let(:solr_expected_creator_array) do
        ['index:1||creator',
         'index:2||creator2']
      end
      let(:work_with_people) do
        Dissertation.new(title: ['New General Work with people'],
                         creators_attributes: { '0' => { name: 'creator',
                                                         affiliation: '',
                                                         other_affiliation: '',
                                                         index: 1 },
                                                '1' => { name: 'creator2',
                                                         affiliation: '',
                                                         other_affiliation: '',
                                                         index: 2 } })
      end
      it 'does not index the empty string to Solr' do
        expect(solr_creator_array).to match_array(solr_expected_creator_array)
        expect(solr_doc.keys.include?('affiliation_label_tesim')).to be false
        expect(solr_doc.keys.include?('affiliation_label_sim')).to be false
      end

      it 'saves the empty string to Fedora' do
        expect(fedora_creator_hash_one['affiliation'].to_a).to eq([''])
        expect(fedora_creator_hash_one['other_affiliation'].to_a).to eq([''])
      end
    end

    context 'with uncontrolled vocabulary in affiliation' do
      let(:work_with_people) do
        General.new(title: ['New General Work with people'],
                    creators_attributes: { '0' => { name: 'creator',
                                                    affiliation: 'not-a-department',
                                                    index: 1 },
                                           '1' => { name: 'creator2',
                                                    affiliation: 'not-a-department',
                                                    index: 2 } })
      end

      let(:solr_expected_creator_array) do
        ['index:1||creator',
         'index:2||creator2']
      end

      it 'does not map the affiliations to solr' do
        expect(solr_creator_array).to match_array(solr_expected_creator_array)
      end

      it 'does not index the uncontrolled term to Solr' do
        expect(solr_doc.keys.include?('affiliation_label_tesim')).to be false
        expect(solr_doc.keys.include?('affiliation_label_sim')).to be false
      end

      it 'stores the id in Fedora' do
        expect(fedora_creator_hash_one['affiliation']).to eq(['not-a-department'])
      end
    end
  end
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

    context 'with a mix of submitted and unsubmitted index values' do
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
