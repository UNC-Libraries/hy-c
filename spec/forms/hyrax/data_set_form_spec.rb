# frozen_string_literal: true
# Generated via
#  `rails generate hyrax:work DataSet`
require 'rails_helper'

RSpec.describe Hyrax::DataSetForm do
  let(:work) { DataSet.new }
  let(:form) { described_class.new(work, nil, nil) }

  describe '#required_fields' do
    subject { form.required_fields }

    it { is_expected.to match_array [:title, :creator, :date_issued, :abstract, :methodology, :kind_of_data, :resource_type] }
  end

  describe '#primary_terms' do
    subject { form.primary_terms }

    it { is_expected.to match_array [:title, :creator, :date_issued, :abstract, :methodology, :kind_of_data, :resource_type] }
  end

  describe '#secondary_terms' do
    subject { form.secondary_terms }

    it {
      is_expected.to match_array [:based_near, :dcmi_type, :copyright_date, :doi, :extent, :funder,
                                  :last_modified_date, :project_director, :researcher, :rights_holder, :sponsor,
                                  :language, :keyword, :related_url, :license, :note, :contributor, :subject,
                                  :rights_statement, :language_label, :license_label, :rights_statement_label,
                                  :deposit_agreement, :agreement, :admin_note, :access_right, :alternative_title, :rights_notes]
    }
  end

  describe '#admin_only_terms' do
    subject { form.admin_only_terms }

    it {
      is_expected.to match_array [:dcmi_type, :access, :doi, :extent, :rights_holder, :rights_statement,
                                  :copyright_date, :admin_note]
    }
  end

  describe 'default value set' do
    subject { form }
    it 'dcmi type must have default values' do
      expect(form.model['dcmi_type']).to eq ['http://purl.org/dc/dcmitype/Dataset']
    end

    it 'rights statement must have a default value' do
      expect(form.model['rights_statement']).to eq 'http://rightsstatements.org/vocab/InC/1.0/'
    end

    it 'language must have default values' do
      expect(form.model['language']).to eq ['http://id.loc.gov/vocabulary/iso639-2/eng']
    end
  end

  describe '.model_attributes' do
    let(:params) do
      ActionController::Parameters.new(
        title: 'data set name', # single-valued
        visibility: 'open',
        representative_id: '456',
        thumbnail_id: '789',
        keyword: ['data set'],
        member_of_collection_ids: ['123456', 'abcdef'],
        abstract: ['an abstract'],
        access: 'public',
        contributors_attributes: { '0' => { name: 'contributor',
                                            orcid: 'contributor orcid',
                                            affiliation: 'Carolina Center for Genome Sciences',
                                            other_affiliation: 'another affiliation' } },
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
        date_issued: '2018-01-08',
        dcmi_type: ['http://purl.org/dc/dcmitype/Dataset'],
        copyright_date: '2018',
        doi: '12345',
        extent: ['1993'],
        funder: ['dean'],
        based_near: ['California'],
        kind_of_data: 'some data',
        last_modified_date: '2018-01-23',
        language: ['http://id.loc.gov/vocabulary/iso639-2/eng'],
        license: 'http://creativecommons.org/licenses/by/3.0/us/',
        methodology: 'My methods',
        note: ['my note'],
        project_directors_attributes: { '0' => { name: 'project director',
                                                 orcid: 'project director orcid',
                                                 affiliation: 'Carolina Center for Genome Sciences',
                                                 other_affiliation: 'another affiliation' } },
        researchers_attributes: { '0' => { name: 'researcher',
                                           orcid: 'researcher orcid',
                                           affiliation: 'Carolina Center for Genome Sciences',
                                           other_affiliation: 'another affiliation' } },
        rights_holder: ['dean'],
        rights_statement: 'http://rightsstatements.org/vocab/InC/1.0/',
        sponsor: ['david'],
        use: ['a usage'],
        language_label: [],
        license_label: [],
        rights_statement_label: ''
      )
    end

    subject { described_class.model_attributes(params) }

    it 'permits parameters' do
      expect(subject['title']).to eq ['data set name']
      expect(subject['visibility']).to eq 'open'
      expect(subject['keyword']).to eq ['data set']
      expect(subject['member_of_collection_ids']).to eq ['123456', 'abcdef']
      expect(subject['abstract']).to eq ['an abstract']
      expect(subject['copyright_date']).to eq '2018'
      expect(subject['date_issued']).to eq '2018-01-08'
      expect(subject['doi']).to eq '12345'
      expect(subject['extent']).to eq ['1993']
      expect(subject['funder']).to eq ['dean']
      expect(subject['dcmi_type']).to eq ['http://purl.org/dc/dcmitype/Dataset']
      expect(subject['based_near']).to eq ['California']
      expect(subject['kind_of_data']).to eq 'some data'
      expect(subject['last_modified_date']).to eq '2018-01-23'
      expect(subject['language']).to eq ['http://id.loc.gov/vocabulary/iso639-2/eng']
      expect(subject['license']).to eq ['http://creativecommons.org/licenses/by/3.0/us/']
      expect(subject['methodology']).to eq 'My methods'
      expect(subject['note']).to eq ['my note']
      expect(subject['rights_holder']).to eq ['dean']
      expect(subject['sponsor']).to eq ['david']
      expect(subject['language_label']).to eq ['English']
      expect(subject['license_label']).to eq ['Attribution 3.0 United States']
      expect(subject['rights_statement_label']).to eq 'In Copyright'
      expect(subject['creators_attributes']['0']['name']).to eq 'creator'
      expect(subject['creators_attributes']['0']['orcid']).to eq 'creator orcid'
      expect(subject['creators_attributes']['0']['affiliation']).to eq 'Carolina Center for Genome Sciences'
      expect(subject['creators_attributes']['0']['other_affiliation']).to eq 'another affiliation'
      expect(subject['creators_attributes']['0']['index']).to eq 1
      expect(subject['creators_attributes']['1']['name']).to eq 'creator2'
      expect(subject['creators_attributes']['1']['orcid']).to eq 'creator2 orcid'
      expect(subject['creators_attributes']['1']['affiliation']).to eq 'Department of Chemistry'
      expect(subject['creators_attributes']['1']['other_affiliation']).to eq 'another affiliation'
      expect(subject['creators_attributes']['1']['index']).to eq 2
      expect(subject['contributors_attributes']['0']['name']).to eq 'contributor'
      expect(subject['contributors_attributes']['0']['orcid']).to eq 'contributor orcid'
      expect(subject['contributors_attributes']['0']['affiliation']).to eq 'Carolina Center for Genome Sciences'
      expect(subject['contributors_attributes']['0']['other_affiliation']).to eq 'another affiliation'
      expect(subject['contributors_attributes']['0']['index']).to eq 1
      expect(subject['project_directors_attributes']['0']['name']).to eq 'project director'
      expect(subject['project_directors_attributes']['0']['orcid']).to eq 'project director orcid'
      expect(subject['project_directors_attributes']['0']['affiliation']).to eq 'Carolina Center for Genome Sciences'
      expect(subject['project_directors_attributes']['0']['other_affiliation']).to eq 'another affiliation'
      expect(subject['project_directors_attributes']['0']['index']).to eq 1
      expect(subject['researchers_attributes']['0']['name']).to eq 'researcher'
      expect(subject['researchers_attributes']['0']['orcid']).to eq 'researcher orcid'
      expect(subject['researchers_attributes']['0']['affiliation']).to eq 'Carolina Center for Genome Sciences'
      expect(subject['researchers_attributes']['0']['other_affiliation']).to eq 'another affiliation'
      expect(subject['researchers_attributes']['0']['index']).to eq 1
    end

    context '.model_attributes' do
      let(:params) do
        ActionController::Parameters.new(
          title: '',
          keyword: [''],
          language_label: [],
          license: '',
          member_of_collection_ids: [''],
          rights_statement: 'http://rightsstatements.org/vocab/InC/1.0/',
          on_behalf_of: 'Melissa'
        )
      end

      it 'removes blank parameters' do
        expect(subject['title']).to be_nil
        expect(subject['license']).to be_nil
        expect(subject['keyword']).to be_empty
        expect(subject['member_of_collection_ids']).to be_empty
        expect(subject['on_behalf_of']).to eq 'Melissa'
      end
    end

    context 'with people parameters' do
      let(:params) do
        ActionController::Parameters.new(
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
          contributors_attributes: { '0' => { name: 'contributor',
                                              orcid: 'contributor orcid',
                                              affiliation: 'Carolina Center for Genome Sciences',
                                              other_affiliation: 'another affiliation' },
                                     '1' => { name: 'contributor2',
                                              orcid: 'contributor2 orcid',
                                              affiliation: 'Department of Chemistry',
                                              other_affiliation: 'another affiliation' } }
        )
      end

      it 'retains existing index values and adds missing index values' do
        expect(subject['creators_attributes'].as_json).to include({ '0' => { 'name' => 'creator',
                                                                             'orcid' => 'creator orcid',
                                                                             'affiliation' => 'Carolina Center for Genome Sciences',
                                                                             'other_affiliation' => 'another affiliation',
                                                                             'index' => 2 },
                                                                    '1' => { 'name' => 'creator2',
                                                                             'orcid' => 'creator2 orcid',
                                                                             'affiliation' => 'Department of Chemistry',
                                                                             'other_affiliation' => 'another affiliation',
                                                                             'index' => 1 },
                                                                    '2' => { 'name' => 'creator3',
                                                                             'orcid' => 'creator3 orcid',
                                                                             'affiliation' => 'Department of Chemistry',
                                                                             'other_affiliation' => 'another affiliation',
                                                                             'index' => 3 } })
        expect(subject['contributors_attributes'].as_json).to include({ '0' => { 'name' => 'contributor',
                                                                                 'orcid' => 'contributor orcid',
                                                                                 'affiliation' => 'Carolina Center for Genome Sciences',
                                                                                 'other_affiliation' => 'another affiliation',
                                                                                 'index' => 1 },
                                                                        '1' => { 'name' => 'contributor2',
                                                                                 'orcid' => 'contributor2 orcid',
                                                                                 'affiliation' => 'Department of Chemistry',
                                                                                 'other_affiliation' => 'another affiliation',
                                                                                 'index' => 2 } })
      end
    end
  end

  describe '#visibility' do
    subject { form.visibility }

    it { is_expected.to eq 'restricted' }
  end

  describe '#agreement_accepted' do
    subject { form.agreement_accepted }

    it { is_expected.to eq false }
  end

  context 'on a work already saved' do
    before { allow(work).to receive(:new_record?).and_return(false) }
    it 'defaults deposit agreement to true' do
      expect(form.agreement_accepted).to eq(true)
    end
  end
end
