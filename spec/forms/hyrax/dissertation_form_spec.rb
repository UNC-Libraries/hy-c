# Generated via
#  `rails generate hyrax:work Dissertation`
require 'rails_helper'

RSpec.describe Hyrax::DissertationForm do
  let(:work) { Dissertation.new }
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

    it { is_expected.to match_array [:abstract, :academic_concentration, :affiliation, :access, :advisor,
                                     :date_issued, :degree, :discipline, :doi, :format, :genre, :graduation_year, :note,
                                     :place_of_publication, :record_content_source, :reviewer, :contributor,
                                     :identifier, :subject, :publisher, :language, :keyword, :rights_statement,
                                     :license, :resource_type] }
  end

  describe '.model_attributes' do
    let(:params) do
      ActionController::Parameters.new(
          title: 'foo', # single-valued
          note: [''],
          visibility: 'open',
          representative_id: '456',
          thumbnail_id: '789',
          keyword: ['derp'],
          member_of_collection_ids: ['123456', 'abcdef'],
          abstract: ['an abstract'],
          affiliation: ['biology'],
          access: 'public',
          date_issued: '2018-01-08',
          degree: 'MSIS',
          degree_granting_institution: 'UNC',
          doi: 'hi.org',
          graduation_year: '2017',
          record_content_source: 'journal'
      )
    end

    subject { described_class.model_attributes(params) }

    it 'permits parameters' do
      expect(subject['title']).to eq ['foo']
      expect(subject['note']).to be_empty
      expect(subject['visibility']).to eq 'open'
      expect(subject['keyword']).to eq ['derp']
      expect(subject['member_of_collection_ids']).to eq ['123456', 'abcdef']
      expect(subject['abstract']).to eq ['an abstract']
      expect(subject['affiliation']).to eq ['biology']
      expect(subject['access']).to eq 'public'
      expect(subject['date_issued']).to eq '2018-01-08'
      expect(subject['degree']).to eq 'MSIS'
      expect(subject['degree_granting_institution']).to eq 'UNC'
      expect(subject['doi']).to eq 'hi.org'
      expect(subject['graduation_year']).to eq '2017'
      expect(subject['record_content_source']).to eq 'journal'
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
        expect(subject['title']).to be_empty
        expect(subject['abstract']).to be_empty
        expect(subject['keyword']).to be_empty
        expect(subject['access']).to be_empty
        expect(subject['degree']).to be_empty
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
