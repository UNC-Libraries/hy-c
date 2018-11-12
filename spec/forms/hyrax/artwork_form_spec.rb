# Generated via
#  `rails generate hyrax:work Artwork`
require 'rails_helper'

RSpec.describe Hyrax::ArtworkForm do
  let(:work) { Artwork.new }
  let(:form) { described_class.new(work, nil, nil) }

  describe "#required_fields" do
    subject { form.required_fields }

    it { is_expected.to match_array [:title, :date_issued, :abstract, :extent, :medium, :resource_type] }
  end

  describe "#primary_terms" do
    subject { form.primary_terms }

    it { is_expected.to match_array [:title, :date_issued, :abstract, :extent, :medium, :resource_type] }
  end

  describe "#secondary_terms" do
    subject { form.secondary_terms }

    it { is_expected.to match_array [:date_created, :description, :license, :rights_statement, :doi, :license_label, :rights_statement_label] }
  end

  describe 'default value set' do
    subject { form }
    it "rights statement must have a default value" do
      expect(form.model['rights_statement']).to eq 'http://rightsstatements.org/vocab/InC/1.0/'
    end
  end

  describe '.model_attributes' do
    let(:params) do
      ActionController::Parameters.new(
          title: 'foo', # single-valued
          date_created: '2017-01-22', # single-valued
          date_issued: '2017-01-22', # single-valued
          resource_type: ['a type'],
          rights_statement: 'http://rightsstatements.org/vocab/InC/1.0/', # single-valued
          subject: ['a subject'],
          visibility: 'open',
          representative_id: '456',
          thumbnail_id: '789',
          license: 'http://creativecommons.org/licenses/by/3.0/us/', # single-valued
          member_of_collection_ids: ['123456', 'abcdef'],
          abstract: ['my abstract'],
          doi: '12345', # single-valued
          extent: '1993',
          medium: 'wood',
          license_label: [],
          rights_statement_label: ''
      )
    end

    subject { described_class.model_attributes(params) }

    it 'permits parameters' do
      expect(subject['title']).to eq ['foo']
      expect(subject['date_created']).to eq '2017-01-22'
      expect(subject['date_issued']).to eq '2017-01-22'
      expect(subject['resource_type']).to eq ['a type']
      expect(subject['rights_statement']).to eq 'http://rightsstatements.org/vocab/InC/1.0/'
      expect(subject['visibility']).to eq 'open'
      expect(subject['license']).to eq ['http://creativecommons.org/licenses/by/3.0/us/']
      expect(subject['member_of_collection_ids']).to eq ['123456', 'abcdef']
      expect(subject['abstract']).to eq ['my abstract']
      expect(subject['doi']).to eq '12345'
      expect(subject['extent']).to eq '1993'
      expect(subject['medium']).to eq 'wood'
      expect(subject['license_label']).to eq ['Attribution 3.0 United States']
      expect(subject['rights_statement_label']).to eq 'In Copyright'
    end

    context '.model_attributes' do
      let(:params) do
        ActionController::Parameters.new(
            title: '',
            license: '',
            member_of_collection_ids: [''],
            rights_statement: 'http://rightsstatements.org/vocab/InC/1.0/',
            on_behalf_of: 'Melissa'
        )
      end

      it 'removes blank parameters' do
        expect(subject['title']).to be_nil
        expect(subject['license']).to be_nil
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
