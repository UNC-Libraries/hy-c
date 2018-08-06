# Generated via
#  `rails generate hyrax:work ScholarlyWork`
require 'rails_helper'

RSpec.describe Hyrax::ScholarlyWorkForm do
  let(:work) { ScholarlyWork.new }
  let(:form) { described_class.new(work, nil, nil) }

  describe "#required_fields" do
    subject { form.required_fields }

    it { is_expected.to match_array [:title, :creator, :date_created] }
  end

  describe "#primary_terms" do
    subject { form.primary_terms }

    it { is_expected.to match_array [:title, :creator, :date_created] }
  end

  describe "#secondary_terms" do
    subject { form.secondary_terms }

    it { is_expected.to match_array [:abstract, :advisor, :conference_name, :date_issued, :doi,
                                     :geographic_subject, :description, :keyword, :language, :license, :resource_type,
                                     :rights_statement, :subject] }
  end
  
  describe "#suppressed_terms" do
    subject { form.suppressed_terms }

    it { is_expected.to match_array [:dcmi_type] }
  end

  describe '.model_attributes' do
    let(:params) do
      ActionController::Parameters.new(
          title: 'foo', # single-valued
          creator: ['someone@example.com'],
          date_created: 'a date', # single-valued
          description: ['a description'],
          subject: ['a subject'],
          language: ['a language'],
          keyword: ['test'],
          resource_type: ['a type'],
          license: 'http://creativecommons.org/licenses/by/3.0/us/', # single-valued
          rights_statement: 'a statement', # single-valued
          member_of_collection_ids: ['123456', 'abcdef'],
          visibility: 'open',
          representative_id: '456',
          thumbnail_id: '789',
          abstract: [''],
          advisor: ['an advisor'],
          conference_name: ['a conference name'],
          date_issued: 'a date', # single-valued
          doi: '12345',
          geographic_subject: ['a geographic subject']
      )
    end

    subject { described_class.model_attributes(params) }

    it 'permits parameters' do
      expect(subject['title']).to eq ['foo']
      expect(subject['creator']).to eq ['someone@example.com']
      expect(subject['date_created']).to eq 'a date'
      expect(subject['description']).to eq ['a description']
      expect(subject['doi']).to eq '12345'
      expect(subject['subject']).to eq ['a subject']
      expect(subject['language']).to eq ['a language']
      expect(subject['keyword']).to eq ['test']
      expect(subject['resource_type']).to eq ['a type']
      expect(subject['license']).to eq ['http://creativecommons.org/licenses/by/3.0/us/']
      expect(subject['rights_statement']).to eq ['a statement']
      expect(subject['visibility']).to eq 'open'
      expect(subject['representative_id']).to eq '456'
      expect(subject['thumbnail_id']).to eq '789'
      expect(subject['abstract']).to be_empty
      expect(subject['conference_name']).to eq ['a conference name']
      expect(subject['date_issued']).to eq 'a date'
      expect(subject['dcmi_type']).to be_empty
      expect(subject['geographic_subject']).to eq ['a geographic subject']
      expect(subject['member_of_collection_ids']).to eq ['123456', 'abcdef']
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
