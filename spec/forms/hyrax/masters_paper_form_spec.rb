# Generated via
#  `rails generate hyrax:work MastersPaper`
require 'rails_helper'

RSpec.describe Hyrax::MastersPaperForm do
  let(:work) { MastersPaper.new }
  let(:form) { described_class.new(work, nil, nil) }

  describe "#required_fields" do
    subject { form.required_fields }

    it { is_expected.to match_array [:title, :creator, :abstract, :advisor, :date_issued, :degree, :resource_type,
                                     :degree_granting_institution, :graduation_year] }
  end

  describe "#primary_terms" do
    subject { form.primary_terms }

    it { is_expected.to match_array [:title, :creator, :abstract, :advisor, :date_issued, :degree, :resource_type,
                                     :degree_granting_institution, :graduation_year] }
  end

  describe "#secondary_terms" do
    subject { form.secondary_terms }

    it { is_expected.to match_array [:academic_concentration, :access, :affiliation, :affiliation_label,
                                     :dcmi_type, :doi, :extent, :geographic_subject, :note, :orcid, :reviewer, :use,
                                     :keyword, :subject, :language, :rights_statement, :license, :language_label,
                                     :license_label, :rights_statement_label] }
  end
  
  describe "#admin_only_terms" do
    subject { form.admin_only_terms }

    it { is_expected.to match_array [:dcmi_type] }
  end
  
  describe 'default value set' do
    subject { form }
    it "dcmi type must have default values" do
      expect(form.model['dcmi_type']).to eq ['http://purl.org/dc/dcmitype/Text'] 
    end
  end

  describe '.model_attributes' do
    let(:params) do
      ActionController::Parameters.new(
          title: 'foo', # single-valued
          creator: ['a creator'],
          subject: ['a subject'],
          language: ['http://id.loc.gov/vocabulary/iso639-2/eng'],
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
          advisor: ['an advisor'],
          affiliation: ['Carolina Center for Genome Sciences', ''],
          affiliation_label: ['School of Medicine', 'Carolina Center for Genome Sciences'],
          date_issued: 'a date', # single-valued
          dcmi_type: ['type'],
          degree: 'MS', # single-valued
          degree_granting_institution: 'UNC', # single-valued
          doi: '12345',
          extent: ['an extent'],
          geographic_subject: ['a geographic subject'],
          graduation_year: '2017',
          note: ['a note'],
          orcid: ['an orcid'],
          reviewer: ['a reviewer'],
          use: ['a use'],
          language_label: [],
          license_label: [],
          rights_statement_label: []
      )
    end

    subject { described_class.model_attributes(params) }

    it 'permits parameters' do
      expect(subject['title']).to eq ['foo']
      expect(subject['creator']).to eq ['a creator']
      expect(subject['subject']).to eq ['a subject']
      expect(subject['language']).to eq ['http://id.loc.gov/vocabulary/iso639-2/eng']
      expect(subject['license']).to eq ['http://creativecommons.org/licenses/by/3.0/us/']
      expect(subject['rights_statement']).to eq ['http://rightsstatements.org/vocab/InC/1.0/']
      expect(subject['resource_type']).to eq ['a type']
      expect(subject['keyword']).to eq ['derp']
      expect(subject['visibility']).to eq 'open'
      expect(subject['member_of_collection_ids']).to eq ['123456', 'abcdef']

      expect(subject['abstract']).to be_empty
      expect(subject['academic_concentration']).to eq ['a concentration']
      expect(subject['access']).to eq 'public'
      expect(subject['advisor']).to eq ['an advisor']
      expect(subject['affiliation']).to eq ['Carolina Center for Genome Sciences']
      expect(subject['affiliation_label']).to eq ['School of Medicine', 'Carolina Center for Genome Sciences']
      expect(subject['date_issued']).to eq 'a date'
      expect(subject['degree']).to eq 'MS'
      expect(subject['degree_granting_institution']).to eq 'UNC'
      expect(subject['doi']).to eq '12345'
      expect(subject['extent']).to eq ['an extent']
      expect(subject['dcmi_type']).to eq ['type']
      expect(subject['geographic_subject']).to eq ['a geographic subject']
      expect(subject['graduation_year']).to eq '2017'
      expect(subject['note']).to eq ['a note']
      expect(subject['orcid']).to eq ['an orcid']
      expect(subject['reviewer']).to eq ['a reviewer']
      expect(subject['use']).to eq ['a use']
      expect(subject['language_label']).to eq ['English']
      expect(subject['license_label']).to eq ['Attribution 3.0 United States']
      expect(subject['rights_statement_label']).to eq ['In Copyright']
    end

    context '.model_attributes' do
      let(:params) do
        ActionController::Parameters.new(
            title: '',
            abstract: [''],
            keyword: [''],
            license: '',
            member_of_collection_ids: [''],
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
