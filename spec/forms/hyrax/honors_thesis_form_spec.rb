# Generated via
#  `rails generate hyrax:work HonorsThesis`
require 'rails_helper'

RSpec.describe Hyrax::HonorsThesisForm do
  let(:work) { HonorsThesis.new }
  let(:form) { described_class.new(work, nil, nil) }

  describe "#required_fields" do
    subject { form.required_fields }

    it { is_expected.to match_array [:title, :creator, :degree_granting_institution] }
  end

  describe "#primary_terms" do
    subject { form.primary_terms }

    it { is_expected.to match_array [:title, :creator, :degree_granting_institution] }
  end

  describe "#secondary_terms" do
    subject { form.secondary_terms }

    it { is_expected.to match_array [:abstract, :affiliation, :advisor, :license, :resource_type,
                                     :rights_statement, :subject, :language, :degree, :genre, :graduation_year,
                                     :honors_level, :note, :academic_concentration, :keyword, :related_url, :access] }
  end

  describe '.model_attributes' do
    let(:params) do
      ActionController::Parameters.new(
          title: 'foo', # single-valued
          abstract: [''],
          creator: ['someone@example.com'],
          visibility: 'open',
          representative_id: '456',
          thumbnail_id: '789',
          degree_granting_institution: 'UNC',
          keyword: ['test'],
          affiliation: ['biology'],
          access: 'public',
          degree: 'MS',
          graduation_year: '2017',
          license: ['http://creativecommons.org/licenses/by/3.0/us/'],
          member_of_collection_ids: ['123456', 'abcdef']
      )
    end

    subject { described_class.model_attributes(params) }

    it 'permits parameters' do
      expect(subject['title']).to eq ['foo']
      expect(subject['abstract']).to be_empty
      expect(subject['creator']).to eq ['someone@example.com']
      expect(subject['visibility']).to eq 'open'
      expect(subject['representative_id']).to eq '456'
      expect(subject['thumbnail_id']).to eq '789'
      expect(subject['degree_granting_institution']).to eq 'UNC'
      expect(subject['affiliation']).to eq ['biology']
      expect(subject['license']).to eq ['http://creativecommons.org/licenses/by/3.0/us/']
      expect(subject['keyword']).to eq ['test']
      expect(subject['access']).to eq 'public'
      expect(subject['degree']).to eq 'MS'
      expect(subject['graduation_year']).to eq '2017'
      expect(subject['member_of_collection_ids']).to eq ['123456', 'abcdef']
    end

    context '.model_attributes' do
      let(:params) do
        ActionController::Parameters.new(
            title: '',
            abstract: [''],
            keyword: [''],
            license: [''],
            member_of_collection_ids: [''],
            on_behalf_of: 'Melissa'
        )
      end

      it 'removes blank parameters' do
        expect(subject['title']).to be_nil
        expect(subject['abstract']).to be_empty
        expect(subject['license']).to be_empty
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
