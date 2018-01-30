# Generated via
#  `rails generate hyrax:work Journal`
require 'rails_helper'

RSpec.describe Hyrax::JournalForm do
  let(:work) { Journal.new }
  let(:form) { described_class.new(work, nil, nil) }

  describe "#required_fields" do
    subject { form.required_fields }

    it { is_expected.to match_array [:title, :creator, :rights_statement, :date_issued, :resource_type] }
  end

  describe "#primary_terms" do
    subject { form.primary_terms }

    it { is_expected.to match_array [:title, :creator, :rights_statement, :date_issued, :resource_type] }
  end

  describe "#secondary_terms" do
    subject { form.secondary_terms }

    it { is_expected.to match_array [:abstract, :alternate_title, :access, :extent, :format, :genre,
                                     :geographic_subject, :issn, :note, :place_of_publication,
                                     :record_content_source, :reviewer, :contributor,
                                     :identifier, :subject, :publisher, :language, :keyword,
                                     :license, :place_of_publication, :table_of_contents] }
  end

  describe ".model_attributes" do
    let(:params) do
      ActionController::Parameters.new(
          title: 'journal name', # single-valued
          note: [''],
          visibility: 'open',
          representative_id: '456',
          thumbnail_id: '789',
          keyword: ['journal'],
          member_of_collection_ids: ['123456', 'abcdef'],
          abstract: ['an abstract'],
          access: 'public',
          alternate_title: 'alt title',
          date_issued: '2018-01-08',
          extent: ['1993'],
          genre: ['science'],
          geographic_subject: ['California'],
          issn: ['12345'],
          place_of_publication: ['California'],
          table_of_contents: ['table of contents'],
          record_content_source: 'journal'
      )
    end

    subject { described_class.model_attributes(params) }

    it "permits parameters" do
      expect(subject['title']).to eq ['journal name']
      expect(subject['note']).to be_empty
      expect(subject['visibility']).to eq 'open'
      expect(subject['keyword']).to eq ['journal']
      expect(subject['member_of_collection_ids']).to eq ['123456', 'abcdef']
      expect(subject['abstract']).to eq ['an abstract']
      expect(subject['access']).to eq 'public'
      expect(subject['date_issued']).to eq '2018-01-08'
      expect(subject['alternate_title']).to eq ['alt_title']
      expect(subject['extent']).to eq ['1993']
      expect(subject['genre']).to eq ['science']
      expect(subject['geographic_subject']).to eq ['California']
      expect(subject['table_of_contents']).to eq ['table of contents']
      expect(subject['record_content_source']).to eq 'journal'
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
