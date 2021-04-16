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

    it { is_expected.to match_array [:abstract, :alternative_title, :based_near, :dcmi_type, :digital_collection,
                                     :doi, :edition, :extent, :isbn, :issn, :note, :place_of_publication, :series,
                                     :creator, :subject, :keyword, :language, :resource_type, :license,
                                     :rights_statement, :language_label, :license_label, :related_url,
                                     :rights_statement_label, :deposit_agreement, :agreement, :admin_note] }
  end
  
  describe "#admin_only_terms" do
    subject { form.admin_only_terms }

    it { is_expected.to match_array [:dcmi_type, :access, :alternative_title, :digital_collection, :doi, :use,
                                     :admin_note] }
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
                                          other_affiliation: 'another affiliation',
                                          index: 1},
                                 '1' => {name: 'creator2',
                                         orcid: 'creator2 orcid',
                                         affiliation: 'Department of Chemistry',
                                         other_affiliation: 'another affiliation',
                                         index: 2} },
          subject: ['a subject'],
          keyword: ['a keyword'],
          language: ['http://id.loc.gov/vocabulary/iso639-2/eng'],
          based_near: ['California'],
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
          dcmi_type: ['http://purl.org/dc/dcmitype/Text'],
          digital_collection: ['my collection'],
          doi: '12345',
          edition: 'First Edition',
          extent: ['1993'],
          isbn: ['123456'],
          issn: ['12345'],
          note: [''],
          place_of_publication: ['California'],
          series: ['series 1'],
          language_label: [],
          license_label: [],
          related_url: ['a url'],
          rights_statement_label: '',
          admin_note: 'My admin note'
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
      expect(subject['based_near']).to eq ['California']
      expect(subject['rights_statement']).to eq 'http://rightsstatements.org/vocab/InC/1.0/'
      expect(subject['publisher']).to eq ['a publisher']
      expect(subject['visibility']).to eq 'open'
      expect(subject['member_of_collection_ids']).to eq ['123456', 'abcdef']
      expect(subject['abstract']).to eq ['an abstract']
      expect(subject['alternative_title']).to eq ['alt title']
      expect(subject['date_issued']).to eq '2018-01-08'
      expect(subject['digital_collection']).to eq ['my collection']
      expect(subject['doi']).to eq '12345'
      expect(subject['edition']).to eq 'First Edition'
      expect(subject['extent']).to eq ['1993']
      expect(subject['dcmi_type']).to eq ['http://purl.org/dc/dcmitype/Text']
      expect(subject['isbn']).to eq ['123456']
      expect(subject['issn']).to eq ['12345']
      expect(subject['note']).to be_empty
      expect(subject['place_of_publication']).to eq ['California']
      expect(subject['series']).to eq ['series 1']
      expect(subject['language_label']).to eq ['English']
      expect(subject['license_label']).to eq ['Attribution 3.0 United States']
      expect(subject['related_url']).to eq ['a url']
      expect(subject['rights_statement_label']).to eq 'In Copyright'
      expect(subject['creators_attributes']['0']['name']).to eq 'creator'
      expect(subject['creators_attributes']['0']['orcid']).to eq 'creator orcid'
      expect(subject['creators_attributes']['0']['affiliation']).to eq 'Carolina Center for Genome Sciences'
      expect(subject['creators_attributes']['0']['other_affiliation']).to eq 'another affiliation'
      expect(subject['creators_attributes']['0']['index']).to eq 1
      expect(subject['creators_attributes']['1']['name']).to eq 'creator2'
      expect(subject['creators_attributes']['1']['orcid']).to eq 'creator2 orcid'
      expect(subject['creators_attributes']['1']['affiliation']).to eq 'Department of Chemistry'
      expect(subject['creators_attributes']['1']['other_affiliation']).to eq 'another affiliation'
      expect(subject['creators_attributes']['1']['index']).to eq 2
      expect(subject['admin_note']).to eq 'My admin note'
    end

    context '.model_attributes' do
      let(:params) do
        ActionController::Parameters.new(
            title: '',
            keyword: [''],
            language_label: [],
            license: '',
            member_of_collection_ids: [''],
            rights_statement: 'http://rightsstatements.org/vocab/InC/1.0/',
            on_behalf_of: 'Melissa'
        )
      end

      it 'removes blank parameters' do
        expect(subject['title']).to be_nil
        expect(subject['license']).to be_nil
        expect(subject['keyword']).to be_empty
        expect(subject['member_of_collection_ids']).to be_empty
        expect(subject['on_behalf_of']).to eq 'Melissa'
      end
    end

    context 'with people parameters' do
      let(:params) do
        ActionController::Parameters.new(
            creators_attributes: { '0' => {name: 'creator',
                                           orcid: 'creator orcid',
                                           affiliation: 'Carolina Center for Genome Sciences',
                                           other_affiliation: 'another affiliation',
                                           index: 2},
                                   '1' => {name: 'creator2',
                                           orcid: 'creator2 orcid',
                                           affiliation: 'Department of Chemistry',
                                           other_affiliation: 'another affiliation',
                                           index: 1},
                                   '2' => {name: 'creator3',
                                           orcid: 'creator3 orcid',
                                           affiliation: 'Department of Chemistry',
                                           other_affiliation: 'another affiliation'}}
        )
      end

      it 'retains existing index values and adds missing index values' do
        expect(subject['creators_attributes'].as_json).to include({'0' => {'name' => 'creator',
                                                                           'orcid' => 'creator orcid',
                                                                           'affiliation' => 'Carolina Center for Genome Sciences',
                                                                           'other_affiliation' => 'another affiliation',
                                                                           'index' => 2},
                                                                   '1' => {'name' => 'creator2',
                                                                           'orcid' => 'creator2 orcid',
                                                                           'affiliation' => 'Department of Chemistry',
                                                                           'other_affiliation' => 'another affiliation',
                                                                           'index' => 1},
                                                                   '2' => {'name' => 'creator3',
                                                                           'orcid' => 'creator3 orcid',
                                                                           'affiliation' => 'Department of Chemistry',
                                                                           'other_affiliation' => 'another affiliation',
                                                                           'index' => 3}})
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
