# Generated via
#  `rails generate hyrax:work Multimedia`
require 'rails_helper'

RSpec.describe Hyrax::MultimediaForm do
  let(:work) { Multimedia.new }
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

    it { is_expected.to match_array [:abstract, :extent, :genre, :geographic_subject, :note, :resource_type] }
  end

  describe ".model_attributes" do
    let(:params) do
      ActionController::Parameters.new(
          title: 'multimedia name', # single-valued
          note: ['a note'],
          keyword: ['multimedia'],
          abstract: ['an abstract'],
          extent: ['1999'],
          genre: ['food'],
          geographic_subject: ['Italy']
      )
    end

    subject { described_class.model_attributes(params) }

    it "permits parameters" do
      expect(subject['title']).to eq ['multimedia name']
      expect(subject['note']).to eq ['a note']
      expect(subject['keyword']).to eq ['multimedia']
      expect(subject['abstract']).to eq ['an abstract']
      expect(subject['extent']).to eq ['1999']
      expect(subject['genre']).to eq ['food']
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
