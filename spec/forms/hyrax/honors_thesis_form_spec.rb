# frozen_string_literal: true
# Generated via
#  `rails generate hyrax:work HonorsThesis`
require 'rails_helper'

RSpec.describe Hyrax::HonorsThesisForm do
  let(:work) { HonorsThesis.new }
  let(:form) { described_class.new(work, nil, nil) }

  describe '#required_fields' do
    subject { form.required_fields }

    # :affiliation requirement enforced in partial
    it do
      is_expected.to match_array [:title, :abstract, :advisor, :creator, :date_issued, :degree,
                                  :graduation_year]
    end
  end

  describe '#primary_terms' do
    subject { form.primary_terms }

    it do
      is_expected.to match_array [:title, :abstract, :advisor, :creator, :date_issued, :degree,
                                  :graduation_year]
    end
  end

  describe '#secondary_terms' do
    subject { form.secondary_terms }

    it {
      is_expected.to match_array [:academic_concentration, :award, :based_near, :dcmi_type, :doi,
                                  :extent, :note, :language, :license, :resource_type,
                                  :rights_statement, :subject, :keyword, :related_url, :language_label,
                                  :license_label, :rights_statement_label, :degree_granting_institution,
                                  :deposit_agreement, :agreement, :admin_note, :access_right,
                                  :alternative_title, :rights_notes]
    }
  end

  describe '#admin_only_terms' do
    subject { form.admin_only_terms }

    it {
      is_expected.to match_array [:dcmi_type, :academic_concentration, :award,
                                  :degree_granting_institution, :doi, :extent, :admin_note, :access_right, :rights_notes]
    }
  end

  describe 'default value set' do
    subject { form }
    it 'dcmi type must have default values' do
      expect(form.model['dcmi_type']).to eq ['http://purl.org/dc/dcmitype/Text']
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
        title: 'foo', # single-valued
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
        keyword: ['a keyword'],
        language: ['http://id.loc.gov/vocabulary/iso639-2/eng'],
        based_near: ['California'],
        license: 'http://creativecommons.org/licenses/by/3.0/us/', # single-valued
        resource_type: ['a type'],
        rights_statement: 'http://rightsstatements.org/vocab/InC/1.0/', # single-valued
        subject: ['a subject'],
        visibility: 'open',
        representative_id: '456',
        thumbnail_id: '789',
        member_of_collection_ids: ['123456', 'abcdef'],
        abstract: [''],
        academic_concentration: ['a concentration'],
        access_right: ['public'],
        advisors_attributes: { '0' => { name: 'advisor',
                                        orcid: 'advisor orcid',
                                        affiliation: 'Carolina Center for Genome Sciences',
                                        other_affiliation: 'another affiliation' } },
        award: 'Honors', # single-valued
        dcmi_type: ['http://purl.org/dc/dcmitype/Text'],
        degree: 'MSIS', # single-valued
        degree_granting_institution: 'UNC', # single-valued
        doi: '12345',
        extent: ['an extent'],
        graduation_year: '2017',
        note: [''],
        rights_notes: ['a rights note'],
        language_label: [],
        license_label: [],
        rights_statement_label: ''
      )
    end

    subject { described_class.model_attributes(params) }

    it 'permits parameters' do
      expect(subject['title']).to eq ['foo']
      expect(subject['keyword']).to eq ['a keyword']
      expect(subject['language']).to eq ['http://id.loc.gov/vocabulary/iso639-2/eng']
      expect(subject['based_near']).to eq ['California']
      expect(subject['resource_type']).to eq ['a type']
      expect(subject['rights_statement']).to eq 'http://rightsstatements.org/vocab/InC/1.0/'
      expect(subject['subject']).to eq ['a subject']
      expect(subject['visibility']).to eq 'open'
      expect(subject['representative_id']).to eq '456'
      expect(subject['thumbnail_id']).to eq '789'
      expect(subject['member_of_collection_ids']).to eq ['123456', 'abcdef']
      expect(subject['doi']).to eq '12345'
      expect(subject['abstract']).to be_empty
      expect(subject['academic_concentration']).to eq ['a concentration']
      expect(subject['access_right']).to eq ['public']
      expect(subject['award']).to eq 'Honors'
      expect(subject['degree']).to eq 'MSIS'
      expect(subject['degree_granting_institution']).to eq 'UNC'
      expect(subject['extent']).to eq ['an extent']
      expect(subject['dcmi_type']).to eq ['http://purl.org/dc/dcmitype/Text']
      expect(subject['license']).to eq ['http://creativecommons.org/licenses/by/3.0/us/']
      expect(subject['graduation_year']).to eq '2017'
      expect(subject['note']).to be_empty
      expect(subject['rights_notes']).to eq ['a rights note']
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
      expect(subject['advisors_attributes']['0']['name']).to eq 'advisor'
      expect(subject['advisors_attributes']['0']['orcid']).to eq 'advisor orcid'
      expect(subject['advisors_attributes']['0']['affiliation']).to eq 'Carolina Center for Genome Sciences'
      expect(subject['advisors_attributes']['0']['other_affiliation']).to eq 'another affiliation'
      expect(subject['advisors_attributes']['0']['index']).to eq 1
    end

    context '.model_attributes' do
      let(:params) do
        ActionController::Parameters.new(
          title: '',
          abstract: [''],
          keyword: [''],
          license: '',
          member_of_collection_ids: [''],
          rights_statement: 'http://rightsstatements.org/vocab/InC/1.0/',
          on_behalf_of: 'Melissa'
        )
      end

      it 'removes blank parameters' do
        expect(subject['title']).to be_nil
        expect(subject['abstract']).to be_empty
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
          advisors_attributes: { '0' => { name: 'advisor',
                                          orcid: 'advisor orcid',
                                          affiliation: 'Carolina Center for Genome Sciences',
                                          other_affiliation: 'another affiliation' },
                                 '1' => { name: 'advisor2',
                                          orcid: 'advisor2 orcid',
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
        expect(subject['advisors_attributes'].as_json).to include({ '0' => { 'name' => 'advisor',
                                                                             'orcid' => 'advisor orcid',
                                                                             'affiliation' => 'Carolina Center for Genome Sciences',
                                                                             'other_affiliation' => 'another affiliation',
                                                                             'index' => 1 },
                                                                    '1' => { 'name' => 'advisor2',
                                                                             'orcid' => 'advisor2 orcid',
                                                                             'affiliation' => 'Department of Chemistry',
                                                                             'other_affiliation' => 'another affiliation',
                                                                             'index' => 2 } })
      end
    end
  end

  describe '#visibility' do
    subject { form.visibility }

    it { is_expected.to eq 'open' }
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
