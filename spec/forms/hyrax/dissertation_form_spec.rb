# Generated via
#  `rails generate hyrax:work Dissertation`
require 'rails_helper'

RSpec.describe Hyrax::DissertationForm do
  let(:work) { Dissertation.new }
  let(:form) { described_class.new(work, nil, nil) }

  describe "#required_fields" do
    subject { form.required_fields }

    it { is_expected.to match_array [:title, :creator, :degree_granting_institution, :date_issued] }
  end

  describe "#primary_terms" do
    subject { form.primary_terms }

    it { is_expected.to match_array [:title, :creator, :degree_granting_institution, :date_issued] }
  end

  describe "#secondary_terms" do
    subject { form.secondary_terms }

    it { is_expected.to match_array [:abstract, :academic_concentration, :access, :advisor, :affiliation,
                                     :alternative_title, :dcmi_type, :degree, :doi, :geographic_subject,
                                     :graduation_year, :note, :orcid, :place_of_publication, :reviewer, :use,
                                     :contributor, :identifier, :subject, :publisher, :language, :keyword,
                                     :rights_statement, :license, :resource_type] }
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
          contributor: ['a contributor'],
          creator: ['a creator'],
          identifier: ['an id'],
          keyword: ['a keyword'],
          language: ['a language'],
          license: 'a license', # single-valued
          publisher: ['a publisher'],
          resource_type: ['a type'],
          rights_statement: 'a statement', # single-valued
          subject: ['a subject'],
          visibility: 'open',
          representative_id: '456',
          thumbnail_id: '789',
          member_of_collection_ids: ['123456', 'abcdef'],
          abstract: ['an abstract'],
          academic_concentration: ['a concentration'],
          access: 'public', # single-valued
          advisor: ['an advisor'],
          affiliation: ['SILS'],
          alternative_title: ['another title'],
          date_issued: '2018-01-08', # single-valued
          dcmi_type: ['type'],
          degree: 'MSIS', # single-valued
          degree_granting_institution: 'UNC', # single-valued
          doi: 'hi.org', # single-valued
          geographic_subject: ['a geographic subject'],
          graduation_year: '2017',
          note: [''],
          orcid: ['some id'],
          place_of_publication: ['a place'],
          reviewer: ['a reviewer'],
          use: ['a use']
      )
    end

    subject { described_class.model_attributes(params) }

    it 'permits parameters' do
      expect(subject['title']).to eq ['foo']
      expect(subject['contributor']).to eq ['a contributor']
      expect(subject['creator']).to eq ['a creator']
      expect(subject['identifier']).to eq ['an id']
      expect(subject['keyword']).to eq ['a keyword']
      expect(subject['language']).to eq ['a language']
      expect(subject['license']).to eq ['a license']
      expect(subject['publisher']).to eq ['a publisher']
      expect(subject['resource_type']).to eq ['a type']
      expect(subject['rights_statement']).to eq ['a statement']
      expect(subject['subject']).to eq ['a subject']
      expect(subject['visibility']).to eq 'open'
      expect(subject['member_of_collection_ids']).to eq ['123456', 'abcdef']
      expect(subject['abstract']).to eq ['an abstract']
      expect(subject['academic_concentration']).to eq ['a concentration']
      expect(subject['access']).to eq 'public'
      expect(subject['advisor']).to eq ['an advisor']
      expect(subject['affiliation']).to eq ['SILS']
      expect(subject['alternative_title']).to eq ['another title']
      expect(subject['date_issued']).to eq '2018-01-08'
      expect(subject['degree']).to eq 'MSIS'
      expect(subject['degree_granting_institution']).to eq 'UNC'
      expect(subject['doi']).to eq 'hi.org'
      expect(subject['dcmi_type']).to eq ['type']
      expect(subject['geographic_subject']).to eq ['a geographic subject']
      expect(subject['graduation_year']).to eq '2017'
      expect(subject['note']).to be_empty
      expect(subject['orcid']).to eq ['some id']
      expect(subject['place_of_publication']).to eq ['a place']
      expect(subject['reviewer']).to eq ['a reviewer']
      expect(subject['use']).to eq ['a use']
    end

    context '.model_attributes' do
      let(:params) do
        ActionController::Parameters.new(
            title: '',
            abstract: [''],
            keyword: [''],
            member_of_collection_ids: [''],
            access: '',
            degree: '',
            on_behalf_of: 'Melissa'
        )
      end

      it 'removes blank parameters' do
        expect(subject['title']).to be_nil
        expect(subject['abstract']).to be_empty
        expect(subject['keyword']).to be_empty
        expect(subject['access']).to be_nil
        expect(subject['degree']).to be_nil
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
