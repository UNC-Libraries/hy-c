# Generated via
#  `rails generate hyrax:work MastersPaper`
require 'rails_helper'

RSpec.describe Hyrax::MastersPaperForm do
  let(:work) { MastersPaper.new }
  let(:form) { described_class.new(work, nil, nil) }

  describe "#required_fields" do
    subject { form.required_fields }

    it { is_expected.to match_array [:title, :creator, :abstract, :advisor, :date_issued, :degree, :resource_type,
                                     :graduation_year] }
  end

  describe "#primary_terms" do
    subject { form.primary_terms }

    it { is_expected.to match_array [:title, :creator, :abstract, :advisor, :date_issued, :degree, :resource_type,
                                     :graduation_year] }
  end

  describe "#secondary_terms" do
    subject { form.secondary_terms }

    it { is_expected.to match_array [:academic_concentration, :access, :based_near, :dcmi_type,
                                     :degree_granting_institution, :doi, :extent, :reviewer, :use, :keyword, :subject,
                                     :language, :note, :rights_statement, :license, :language_label, :license_label,
                                     :rights_statement_label, :deposit_agreement, :agreement, :admin_note] }
  end
  
  describe "#admin_only_terms" do
    subject { form.admin_only_terms }

    it { is_expected.to match_array [:dcmi_type, :access, :degree_granting_institution, :doi, :extent, :use,
                                     :admin_note] }
  end
  
  describe 'default value set' do
    subject { form }
    it "dcmi type must have default values" do
      expect(form.model['dcmi_type']).to eq ['http://purl.org/dc/dcmitype/Text'] 
    end

    it "rights statement must have a default value" do
      expect(form.model['rights_statement']).to eq 'http://rightsstatements.org/vocab/InC/1.0/'
    end

    it "language must have default values" do
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
                                          other_affiliation: 'another affiliation'} },
          subject: ['a subject'],
          language: ['http://id.loc.gov/vocabulary/iso639-2/eng'],
          based_near: ['a geographic subject'],
          license: 'http://creativecommons.org/licenses/by/3.0/us/', # single-valued
          rights_statement: 'http://rightsstatements.org/vocab/InC/1.0/', # single-valued
          resource_type: ['a type'],
          visibility: 'open',
          representative_id: '456',
          thumbnail_id: '789',
          keyword: ['derp'],
          member_of_collection_ids: ['123456', 'abcdef'],

          abstract: [''],
          academic_concentration: ['a concentration'],
          access: 'public', # single-valued
          advisors_attributes: { '0' => { name: 'advisor',
                                          orcid: 'advisor orcid',
                                          affiliation: 'Carolina Center for Genome Sciences',
                                          other_affiliation: 'another affiliation'} },
          date_issued: 'Summer 1999', # single-valued
          dcmi_type: ['type'],
          degree: 'MS', # single-valued
          degree_granting_institution: 'UNC', # single-valued
          doi: '12345',
          extent: ['an extent'],
          graduation_year: '2017',
          note: ['a note'],
          reviewers_attributes: { '0' => { name: 'reviewer',
                                          orcid: 'reviewer orcid',
                                          affiliation: 'Carolina Center for Genome Sciences',
                                          other_affiliation: 'another affiliation'} },
          use: ['a use'],
          language_label: [],
          license_label: [],
          rights_statement_label: ''
      )
    end

    subject { described_class.model_attributes(params) }

    it 'permits parameters' do
      expect(subject['title']).to eq ['foo']
      expect(subject['subject']).to eq ['a subject']
      expect(subject['language']).to eq ['http://id.loc.gov/vocabulary/iso639-2/eng']
      expect(subject['license']).to eq ['http://creativecommons.org/licenses/by/3.0/us/']
      expect(subject['based_near']).to eq ['a geographic subject']
      expect(subject['rights_statement']).to eq 'http://rightsstatements.org/vocab/InC/1.0/'
      expect(subject['resource_type']).to eq ['a type']
      expect(subject['keyword']).to eq ['derp']
      expect(subject['visibility']).to eq 'open'
      expect(subject['member_of_collection_ids']).to eq ['123456', 'abcdef']

      expect(subject['abstract']).to be_empty
      expect(subject['academic_concentration']).to eq ['a concentration']
      expect(subject['access']).to eq 'public'
      expect(subject['date_issued']).to eq '1999-22'
      expect(subject['degree']).to eq 'MS'
      expect(subject['degree_granting_institution']).to eq 'UNC'
      expect(subject['doi']).to eq '12345'
      expect(subject['extent']).to eq ['an extent']
      expect(subject['dcmi_type']).to eq ['type']
      expect(subject['graduation_year']).to eq '2017'
      expect(subject['note']).to eq ['a note']
      expect(subject['use']).to eq ['a use']
      expect(subject['language_label']).to eq ['English']
      expect(subject['license_label']).to eq ['Attribution 3.0 United States']
      expect(subject['rights_statement_label']).to eq 'In Copyright'
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
  end

  describe "#visibility" do
    subject { form.visibility }

    it { is_expected.to eq 'restricted' }
  end

  describe "#agreement_accepted" do
    subject { form.agreement_accepted }

    it { is_expected.to eq false }
  end

  context "on a work already saved" do
    before { allow(work).to receive(:new_record?).and_return(false) }
    it "defaults deposit agreement to true" do
      expect(form.agreement_accepted).to eq(true)
    end
  end
end
