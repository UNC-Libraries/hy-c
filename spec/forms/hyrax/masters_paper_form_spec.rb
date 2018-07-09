# Generated via
#  `rails generate hyrax:work MastersPaper`
require 'rails_helper'

RSpec.describe Hyrax::MastersPaperForm do
  let(:work) { MastersPaper.new }
  let(:form) { described_class.new(work, nil, nil) }

  describe "#required_fields" do
    subject { form.required_fields }

    it { is_expected.to match_array [:title, :creator, :date_issued, :degree_granting_institution] }
  end

  describe "#primary_terms" do
    subject { form.primary_terms }

    it { is_expected.to match_array [:title, :creator, :date_issued, :degree_granting_institution] }
  end

  describe "#secondary_terms" do
    subject { form.secondary_terms }

    it { is_expected.to match_array [:abstract, :academic_concentration, :access, :advisor, :degree, :doi, :extent,
                                     :genre, :geographic_subject, :graduation_year, :medium, :note, :reviewer, :use,
                                     :keyword, :subject, :language, :rights_statement, :license, :resource_type] }
  end

  describe '.model_attributes' do
    let(:params) do
      ActionController::Parameters.new(
          title: 'foo', # single-valued
          creator: ['a creator'],
          subject: ['a subject'],
          language: ['a language'],
          license: 'http://creativecommons.org/licenses/by/3.0/us/', # single-valued
          rights_statement: 'a statement', # single-valued
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
          date_issued: 'a date', # single-valued
          degree: 'MS', # single-valued
          degree_granting_institution: 'UNC', # single-valued
          doi: '12345',
          extent: ['an extent'],
          genre: ['a genre'],
          geographic_subject: ['a geographic subject'],
          graduation_year: '2017',
          medium: ['a medium'],
          note: ['a note'],
          reviewer: ['a reviewer'],
          use: ['a use']
      )
    end

    subject { described_class.model_attributes(params) }

    it 'permits parameters' do
      expect(subject['title']).to eq ['foo']
      expect(subject['creator']).to eq ['a creator']
      expect(subject['subject']).to eq ['a subject']
      expect(subject['language']).to eq ['a language']
      expect(subject['license']).to eq ['http://creativecommons.org/licenses/by/3.0/us/']
      expect(subject['rights_statement']).to eq ['a statement']
      expect(subject['resource_type']).to eq ['a type']
      expect(subject['keyword']).to eq ['derp']
      expect(subject['visibility']).to eq 'open'
      expect(subject['member_of_collection_ids']).to eq ['123456', 'abcdef']

      expect(subject['abstract']).to be_empty
      expect(subject['academic_concentration']).to eq ['a concentration']
      expect(subject['access']).to eq 'public'
      expect(subject['advisor']).to eq ['an advisor']
      expect(subject['date_issued']).to eq 'a date'
      expect(subject['degree']).to eq 'MS'
      expect(subject['degree_granting_institution']).to eq 'UNC'
      expect(subject['doi']).to eq '12345'
      expect(subject['extent']).to eq ['an extent']
      expect(subject['genre']).to eq ['a genre']
      expect(subject['geographic_subject']).to eq ['a geographic subject']
      expect(subject['graduation_year']).to eq '2017'
      expect(subject['medium']).to eq ['a medium']
      expect(subject['note']).to eq ['a note']
      expect(subject['reviewer']).to eq ['a reviewer']
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
