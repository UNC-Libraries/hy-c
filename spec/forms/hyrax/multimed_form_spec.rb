# Generated via
#  `rails generate hyrax:work Multimed`
require 'rails_helper'

RSpec.describe Hyrax::MultimedForm do
  let(:work) { Multimed.new }
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

    it { is_expected.to match_array [:abstract, :date_created, :doi, :extent, :geographic_subject, :keyword,
                                     :language, :license, :note, :resource_type, :rights_statement, :subject] }
  end
  
  describe "#suppressed_terms" do
    subject { form.suppressed_terms }

    it { is_expected.to match_array [:dcmi_type] }
  end

  describe ".model_attributes" do
    let(:params) do
      ActionController::Parameters.new(
          title: 'multimed name', # single-valued
          creator: ['a creator'],
          date_created: '2018-01-09', # single-valued
          subject: ['a subject'],
          language: ['a language'],
          note: ['a note'],
          resource_type: ['a type'],
          license: 'a license', # single-valued
          rights_statement: 'a statement', # single-valued
          abstract: ['an abstract'],
          doi: '12345',
          extent: ['1999'],
          geographic_subject: ['Italy'],
          keyword: ['multimed'],
      )
    end

    subject { described_class.model_attributes(params) }

    it "permits parameters" do
      expect(subject['title']).to eq ['multimed name']
      expect(subject['creator']).to eq ['a creator']
      expect(subject['subject']).to eq ['a subject']
      expect(subject['language']).to eq ['a language']
      expect(subject['resource_type']).to eq ['a type']
      expect(subject['license']).to eq ['a license']
      expect(subject['rights_statement']).to eq ['a statement']
      expect(subject['note']).to eq ['a note']
      expect(subject['keyword']).to eq ['multimed']
      expect(subject['abstract']).to eq ['an abstract']
      expect(subject['date_created']).to eq ['2018-01-09']
      expect(subject['doi']).to eq '12345'
      expect(subject['extent']).to eq ['1999']
      expect(subject['dcmi_type']).to be_empty
      expect(subject['geographic_subject']).to eq ['Italy']
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
end
