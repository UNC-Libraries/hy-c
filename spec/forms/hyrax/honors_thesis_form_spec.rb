# Generated via
#  `rails generate hyrax:work HonorsThesis`
require 'rails_helper'

RSpec.describe Hyrax::HonorsThesisForm do
  let(:work) { HonorsThesis.new }
  let(:form) { described_class.new(work, nil, nil) }

  describe "#required_fields" do
    subject { form.required_fields }

    it do  is_expected.to match_array [:title, :abstract, :affiliation, :advisor,
                                       :creator, :degree, :date_created, :graduation_year,]
    end
  end

  describe "#primary_terms" do
    subject { form.primary_terms }

    it do  is_expected.to match_array [:title, :abstract, :affiliation, :advisor,
                                       :creator, :degree, :date_created, :graduation_year,]
    end
  end

  describe "#secondary_terms" do
    subject { form.secondary_terms }

    it { is_expected.to match_array [:access, :academic_concentration, :alternative_title,
                                     :award, :date_issued, :dcmi_type, :degree_granting_institution, :doi, :extent,
                                     :geographic_subject, :note, :use, :language, :license, :resource_type,
                                     :rights_statement, :subject, :keyword, :related_url] }
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
          keyword: ['a keyword'],
          language: ['a language'],
          license: 'a license', # single-valued
          resource_type: ['a type'],
          rights_statement: 'a statement', # single-valued
          subject: ['a subject'],
          visibility: 'open',
          representative_id: '456',
          thumbnail_id: '789',
          member_of_collection_ids: ['123456', 'abcdef'],
          abstract: [''],
          academic_concentration: ['a concentration'],
          access: 'public', # single-valued
          advisor: ['an advisor'],
          affiliation: 'SILS',
          alternative_title: ['another title'],
          award: ['an award'],
          dcmi_type: ['type'],
          degree: 'MSIS', # single-valued
          degree_granting_institution: 'UNC', # single-valued
          doi: '12345',
          extent: ['an extent'],
          geographic_subject: ['a geographic subject'],
          graduation_year: '2017',
          note: [''],
          use: ['a use']
      )
    end

    subject { described_class.model_attributes(params) }

    it 'permits parameters' do
      expect(subject['title']).to eq ['foo']
      expect(subject['creator']).to eq ['a creator']
      expect(subject['keyword']).to eq ['a keyword']
      expect(subject['language']).to eq ['a language']
      expect(subject['license']).to eq ['a license']
      expect(subject['resource_type']).to eq ['a type']
      expect(subject['rights_statement']).to eq ['a statement']
      expect(subject['subject']).to eq ['a subject']
      expect(subject['visibility']).to eq 'open'
      expect(subject['representative_id']).to eq '456'
      expect(subject['thumbnail_id']).to eq '789'
      expect(subject['member_of_collection_ids']).to eq ['123456', 'abcdef']
      expect(subject['doi']).to eq '12345'
      expect(subject['abstract']).to be_empty
      expect(subject['academic_concentration']).to eq ['a concentration']
      expect(subject['access']).to eq 'public'
      expect(subject['advisor']).to eq ['an advisor']
      expect(subject['affiliation']).to eq ['SILS']
      expect(subject['alternative_title']).to eq ['another title']
      expect(subject['award']).to eq ['an award']
      expect(subject['degree']).to eq 'MSIS'
      expect(subject['degree_granting_institution']).to eq 'UNC'
      expect(subject['extent']).to eq ['an extent']
      expect(subject['dcmi_type']).to eq ['type']
      expect(subject['geographic_subject']).to eq ['a geographic subject']
      expect(subject['graduation_year']).to eq '2017'
      expect(subject['note']).to be_empty
      expect(subject['use']).to eq ['a use']
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
