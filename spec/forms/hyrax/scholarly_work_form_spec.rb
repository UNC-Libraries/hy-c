# Generated via
#  `rails generate hyrax:work ScholarlyWork`
require 'rails_helper'

RSpec.describe Hyrax::ScholarlyWorkForm do
  let(:work) { ScholarlyWork.new }
  let(:form) { described_class.new(work, nil, nil) }

  describe "#required_fields" do
    subject { form.required_fields }

    it { is_expected.to match_array [:title, :creator] }
  end

  describe "#primary_terms" do
    subject { form.primary_terms }

    it { is_expected.to match_array [:title, :creator] }
  end

  describe "#secondary_terms" do
    subject { form.secondary_terms }

    it { is_expected.to match_array [:abstract, :advisor, :affiliation, :conference_name, :date_issued, :genre,
                                     :geographic_subject, :orcid, :other_affiliation, :date_created, :description,
                                     :keyword, :language, :license, :resource_type, :rights_statement, :subject] }
  end

  describe '.model_attributes' do
    let(:params) do
      ActionController::Parameters.new(
          title: 'foo', # single-valued
          creator: ['someone@example.com'],
          visibility: 'open',
          representative_id: '456',
          thumbnail_id: '789',
          abstract: [''],
          advisor: ['an advisor'],
          affiliation: ['an affiliation'],
          conference_name: ['a conference name'],
          date_issued: 'a date', # single-valued
          genre: ['a genre'],
          geographic_subject: ['a geographic subject'],
          orcid: ['an orcid id'],
          other_affiliation: ['another affiliation'],
          keyword: ['test'],
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
      expect(subject['license']).to eq ['http://creativecommons.org/licenses/by/3.0/us/']
      expect(subject['keyword']).to eq ['test']
      expect(subject['affiliation']).to eq ['an affiliation']
      expect(subject['other_affiliation']).to eq ['another affiliation']
      expect(subject['conference_name']).to eq ['a conference name']
      expect(subject['date_issued']).to eq 'a date'
      expect(subject['genre']).to eq ['a genre']
      expect(subject['geographic_subject']).to eq ['a geographic subject']
      expect(subject['orcid']).to eq ['an orcid id']
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
        expect(subject['title']).to be_empty
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
