# Generated via
#  `rails generate hyrax:work Journal`
require 'rails_helper'

RSpec.describe Hyrax::JournalForm do
  let(:work) { Journal.new }
  let(:form) { described_class.new(work, nil, nil) }

  describe "#required_fields" do
    subject { form.required_fields }

    it { is_expected.to match_array [:title, :date_issued] }
  end

  describe "#primary_terms" do
    subject { form.primary_terms }

    it { is_expected.to match_array [:title, :date_issued] }
  end

  describe "#secondary_terms" do
    subject { form.secondary_terms }

    it { is_expected.to match_array [:abstract, :alternative_title, :doi, :extent, :geographic_subject, :issn,
                                     :note, :place_of_publication, :table_of_contents, :creator, :subject, :keyword,
                                     :language, :resource_type, :license, :rights_statement, :publisher] }
  end
  
  describe "#suppressed_terms" do
    subject { form.suppressed_terms }

    it { is_expected.to match_array [:dcmi_type] }
  end

  describe ".model_attributes" do
    let(:params) do
      ActionController::Parameters.new(
          title: 'journal name', # single-valued
          creator: ['a creator'],
          subject: ['a subject'],
          keyword: ['a keyword'],
          language: ['a language'],
          resource_type: ['a type'],
          license: 'a license', # single-valued
          rights_statement: 'a statement', # single-valued
          publisher: ['a publisher'],
          visibility: 'open',
          representative_id: '456',
          thumbnail_id: '789',
          member_of_collection_ids: ['123456', 'abcdef'],
          abstract: ['an abstract'],
          alternative_title: ['alt title'],
          date_issued: '2018-01-08', # single-valued
          doi: '12345',
          extent: ['1993'],
          geographic_subject: ['California'],
          issn: ['12345'],
          note: [''],
          place_of_publication: ['California'],
          table_of_contents: ['table of contents']
      )
    end

    subject { described_class.model_attributes(params) }

    it "permits parameters" do
      expect(subject['title']).to eq ['journal name']
      expect(subject['creator']).to eq ['a creator']
      expect(subject['subject']).to eq ['a subject']
      expect(subject['keyword']).to eq ['a keyword']
      expect(subject['language']).to eq ['a language']
      expect(subject['resource_type']).to eq ['a type']
      expect(subject['license']).to eq ['a license']
      expect(subject['rights_statement']).to eq ['a statement']
      expect(subject['publisher']).to eq ['a publisher']
      expect(subject['visibility']).to eq 'open'
      expect(subject['member_of_collection_ids']).to eq ['123456', 'abcdef']
      expect(subject['abstract']).to eq ['an abstract']
      expect(subject['alternative_title']).to eq ['alt title']
      expect(subject['date_issued']).to eq '2018-01-08'
      expect(subject['doi']).to eq '12345'
      expect(subject['extent']).to eq ['1993']
      expect(subject['dcmi_type']).to eq ['http://purl.org/dc/dcmitype/Text']
      expect(subject['geographic_subject']).to eq ['California']
      expect(subject['issn']).to eq ['12345']
      expect(subject['note']).to be_empty
      expect(subject['place_of_publication']).to eq ['California']
      expect(subject['table_of_contents']).to eq ['table of contents']
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
