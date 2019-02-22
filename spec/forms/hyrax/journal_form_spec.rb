# Generated via
#  `rails generate hyrax:work Journal`
require 'rails_helper'

RSpec.describe Hyrax::JournalForm do
  let(:work) { Journal.new }
  let(:form) { described_class.new(work, nil, nil) }

  describe "#required_fields" do
    subject { form.required_fields }

    it { is_expected.to match_array [:title, :date_issued, :publisher] }
  end

  describe "#primary_terms" do
    subject { form.primary_terms }

    it { is_expected.to match_array [:title, :date_issued, :publisher] }
  end

  describe "#secondary_terms" do
    subject { form.secondary_terms }

    it { is_expected.to match_array [:abstract, :alternative_title, :dcmi_type, :digital_collection, :doi, :extent, :geographic_subject,
                                     :isbn, :issn, :note, :place_of_publication, :series, :table_of_contents, :creator,
                                     :subject, :keyword, :language, :resource_type, :license, :rights_statement,
                                     :language_label, :license_label, :rights_statement_label] }
  end
  
  describe "#admin_only_terms" do
    subject { form.admin_only_terms }

    it { is_expected.to match_array [:dcmi_type, :access, :alternative_title, :date_created, :digital_collection, :doi, :use] }
  end
  
  describe 'default value set' do
    subject { form }
    it "dcmi type must have default values" do
      expect(form.model['dcmi_type']).to eq ['http://purl.org/dc/dcmitype/Text']
    end

    it "rights statement must have a default value" do
      expect(form.model['rights_statement']).to eq 'http://rightsstatements.org/vocab/InC/1.0/'
    end

    it "language must have default values" do
      expect(form.model['language']).to eq ['http://id.loc.gov/vocabulary/iso639-2/eng']
    end
  end

  describe ".model_attributes" do
    let(:params) do
      ActionController::Parameters.new(
          title: 'journal name', # single-valued
          creators_attributes: { '0' => { name: 'creator',
                                          orcid: 'creator orcid',
                                          affiliation: 'Carolina Center for Genome Sciences',
                                          other_affiliation: 'another affiliation'} },
          subject: ['a subject'],
          keyword: ['a keyword'],
          language: ['http://id.loc.gov/vocabulary/iso639-2/eng'],
          resource_type: ['a type'],
          license: 'http://creativecommons.org/licenses/by/3.0/us/', # single-valued
          rights_statement: 'http://rightsstatements.org/vocab/InC/1.0/', # single-valued
          publisher: ['a publisher'],
          visibility: 'open',
          representative_id: '456',
          thumbnail_id: '789',
          member_of_collection_ids: ['123456', 'abcdef'],
          abstract: ['an abstract'],
          alternative_title: ['alt title'],
          date_issued: '2018-01-08', # single-valued
          dcmi_type: ['type'],
          digital_collection: ['my collection'],
          doi: '12345',
          extent: ['1993'],
          geographic_subject: ['California'],
          isbn: ['123456'],
          issn: ['12345'],
          note: [''],
          place_of_publication: ['California'],
          series: ['series 1'],
          table_of_contents: 'table of contents',
          language_label: [],
          license_label: [],
          rights_statement_label: ''
      )
    end

    subject { described_class.model_attributes(params) }

    it "permits parameters" do
      expect(subject['title']).to eq ['journal name']
      expect(subject['subject']).to eq ['a subject']
      expect(subject['keyword']).to eq ['a keyword']
      expect(subject['language']).to eq ['http://id.loc.gov/vocabulary/iso639-2/eng']
      expect(subject['resource_type']).to eq ['a type']
      expect(subject['license']).to eq ['http://creativecommons.org/licenses/by/3.0/us/']
      expect(subject['rights_statement']).to eq 'http://rightsstatements.org/vocab/InC/1.0/'
      expect(subject['publisher']).to eq ['a publisher']
      expect(subject['visibility']).to eq 'open'
      expect(subject['member_of_collection_ids']).to eq ['123456', 'abcdef']
      expect(subject['abstract']).to eq ['an abstract']
      expect(subject['alternative_title']).to eq ['alt title']
      expect(subject['date_issued']).to eq '2018-01-08'
      expect(subject['digital_collection']).to eq ['my collection']
      expect(subject['doi']).to eq '12345'
      expect(subject['extent']).to eq ['1993']
      expect(subject['dcmi_type']).to eq ['type']
      expect(subject['geographic_subject']).to eq ['California']
      expect(subject['isbn']).to eq ['123456']
      expect(subject['issn']).to eq ['12345']
      expect(subject['note']).to be_empty
      expect(subject['place_of_publication']).to eq ['California']
      expect(subject['series']).to eq ['series 1']
      expect(subject['table_of_contents']).to eq 'table of contents'
      expect(subject['language_label']).to eq ['English']
      expect(subject['license_label']).to eq ['Attribution 3.0 United States']
      expect(subject['rights_statement_label']).to eq 'In Copyright'
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
