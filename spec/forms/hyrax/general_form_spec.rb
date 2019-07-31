# Generated via
#  `rails generate hyrax:work General`
require 'rails_helper'

RSpec.describe Hyrax::GeneralForm do
  let(:work) { General.new }
  let(:form) { described_class.new(work, nil, nil) }

  describe "#required_fields" do
    subject { form.required_fields }

    it { is_expected.to eq [:title, :dcmi_type] }
  end

  describe "#primary_terms" do
    subject { form.primary_terms }

    it { is_expected.to eq [:title, :dcmi_type] }
  end

  describe "#secondary_terms" do
    subject { form.secondary_terms }

    it { is_expected.to match_array [:based_near, :contributor, :creator, :description,
                                     :keyword, :identifier, :language, :license, :publisher, :related_url,
                                     :resource_type, :rights_statement, :subject, :bibliographic_citation, :abstract,
                                     :academic_concentration, :access, :advisor, :alternative_title, :arranger, :award,
                                     :composer, :conference_name, :copyright_date, :date_captured, :date_issued,
                                     :date_other, :degree, :degree_granting_institution, :digital_collection,
                                     :doi, :edition, :extent, :funder, :graduation_year, :isbn, :issn,
                                     :journal_issue, :journal_title, :journal_volume, :kind_of_data, :last_modified_date,
                                     :medium, :methodology, :note, :page_start, :page_end, :peer_review_status,
                                     :place_of_publication, :project_director, :researcher,
                                     :reviewer, :rights_holder, :series, :sponsor, :table_of_contents, :translator,
                                     :use, :language_label, :license_label, :rights_statement_label, :deposit_agreement,
                                     :agreement, :admin_note] }
  end

  describe "#admin_only_terms" do
    subject { form.admin_only_terms }

    it { is_expected.to match_array [:dcmi_type, :degree_granting_institution, :digital_collection, :doi,
                                     :admin_note] }
  end

  describe 'default value set' do
    subject { form }
    it "language must have default values" do
      expect(form.model['language']).to eq ['http://id.loc.gov/vocabulary/iso639-2/eng']
    end
  end

  describe '.model_attributes' do
    let(:params) do
      ActionController::Parameters.new(
          title: 'foo', # single-valued
          bibliographic_citation: ['a citation'],
          contributors_attributes: { '0' => { name: 'contributor',
                                          orcid: 'contributor orcid',
                                          affiliation: 'Carolina Center for Genome Sciences',
                                          other_affiliation: 'another affiliation'} },
          creators_attributes: { '0' => { name: 'creator',
                                          orcid: 'creator orcid',
                                          affiliation: 'Carolina Center for Genome Sciences',
                                          other_affiliation: 'another affiliation'} },
          identifier: ['an identifier'],
          language: ['http://id.loc.gov/vocabulary/iso639-2/eng'],
          based_near: ['California'],
          license: 'http://creativecommons.org/licenses/by/3.0/us/', # single-valued
          keyword: ['derp'],
          publisher: ['a publisher'],
          related_url: ['a url'],
          resource_type: ['a type'],
          rights_statement: 'http://rightsstatements.org/vocab/InC/1.0/', # single-valued
          subject: ['a subject'],
          description: 'a good work', # single-valued
          visibility: 'open',
          representative_id: '456',
          thumbnail_id: '789',
          member_of_collection_ids: ['123456', 'abcdef'],
          abstract: ['an abstract'],
          academic_concentration: ['a concentration'],
          access: 'public', # single-valued
          advisors_attributes: { '0' => { name: 'advisor',
                                          orcid: 'advisor orcid',
                                          affiliation: 'Carolina Center for Genome Sciences',
                                          other_affiliation: 'another affiliation'} },
          alternative_title: ['some title'],
          arrangers_attributes: { '0' => { name: 'arranger',
                                          orcid: 'arranger orcid',
                                          affiliation: 'Carolina Center for Genome Sciences',
                                          other_affiliation: 'another affiliation'} },
          award: 'an award', # single-valued
          composers_attributes: { '0' => { name: 'composer',
                                          orcid: 'composer orcid',
                                          affiliation: 'Carolina Center for Genome Sciences',
                                          other_affiliation: 'another affiliation'} },
          conference_name: ['a conference'],
          copyright_date: ['2017'],
          date_captured: '2017-01-20',
          date_issued: ['2017-01-22'],
          date_other: ['2017-01-22'],
          dcmi_type: ['type'],
          degree: 'something', # single-valued
          degree_granting_institution: 'unc', # single-valued
          digital_collection: ['my collection'],
          doi: '12345', # single-valued
          edition: 'an edition', # single-valued
          extent: ['1993'],
          funder: ['dean'],
          graduation_year: '2018', # single-valued
          isbn: ['123456'],
          issn: ['12345'],
          journal_issue: '27', # single-valued
          journal_title: 'Journal Title', # single-valued
          journal_volume: '4', # single-valued
          kind_of_data: 'a data type',
          last_modified_date: 'hi', # single-valued
          medium: ['a medium'],
          methodology: 'My methodology',
          note: ['a note'],
          page_end: '11', # single-valued
          page_start: '8', # single-valued
          peer_review_status: 'in review', # single-valued
          place_of_publication: ['durham'],
          project_directors_attributes: { '0' => { name: 'project director',
                                          orcid: 'project director orcid',
                                          affiliation: 'Carolina Center for Genome Sciences',
                                          other_affiliation: 'another affiliation'} },
          researchers_attributes: { '0' => { name: 'researcher',
                                          orcid: 'researcher orcid',
                                          affiliation: 'Carolina Center for Genome Sciences',
                                          other_affiliation: 'another affiliation'} },
          reviewers_attributes: { '0' => { name: 'reviewer',
                                          orcid: 'reviewer orcid',
                                          affiliation: 'Carolina Center for Genome Sciences',
                                          other_affiliation: 'another affiliation'} },
          rights_holder: ['dean'],
          series: ['series'],
          sponsor: ['a sponsor'],
          table_of_contents: ['cool table'],
          translators_attributes: { '0' => { name: 'translator',
                                          orcid: 'translator orcid',
                                          affiliation: 'Carolina Center for Genome Sciences',
                                          other_affiliation: 'another affiliation'} },
          use: ['a use'],
          language_label: [],
          license_label: [],
          rights_statement_label: ''
      )
    end

    subject { described_class.model_attributes(params) }

    it 'permits parameters' do
      expect(subject['title']).to eq ['foo']
      expect(subject['bibliographic_citation']).to eq ['a citation']
      expect(subject['identifier']).to eq ['an identifier']
      expect(subject['language']).to eq ['http://id.loc.gov/vocabulary/iso639-2/eng']
      expect(subject['based_near']).to eq ['California']
      expect(subject['publisher']).to eq ['a publisher']
      expect(subject['related_url']).to eq ['a url']
      expect(subject['resource_type']).to eq ['a type']
      expect(subject['rights_statement']).to eq 'http://rightsstatements.org/vocab/InC/1.0/'
      expect(subject['subject']).to eq ['a subject']
      expect(subject['description']).to eq 'a good work'
      expect(subject['visibility']).to eq 'open'
      expect(subject['license']).to eq ['http://creativecommons.org/licenses/by/3.0/us/']
      expect(subject['keyword']).to eq ['derp']
      expect(subject['member_of_collection_ids']).to eq ['123456', 'abcdef']
      expect(subject['abstract']).to eq ['an abstract']
      expect(subject['academic_concentration']).to eq ['a concentration']
      expect(subject['access']).to eq 'public'
      expect(subject['alternative_title']).to eq ['some title']
      expect(subject['award']).to eq 'an award'
      expect(subject['conference_name']).to eq ['a conference']
      expect(subject['copyright_date']).to eq ['2017']
      expect(subject['date_captured']).to eq '2017-01-20'
      expect(subject['date_issued']).to eq ['2017-01-22']
      expect(subject['date_other']).to eq ['2017-01-22']
      expect(subject['degree']).to eq 'something'
      expect(subject['degree_granting_institution']).to eq 'unc'
      expect(subject['digital_collection']).to eq ['my collection']
      expect(subject['doi']).to eq '12345'
      expect(subject['edition']).to eq 'an edition'
      expect(subject['extent']).to eq ['1993']
      expect(subject['funder']).to eq ['dean']
      expect(subject['dcmi_type']).to eq ['type']
      expect(subject['graduation_year']).to eq '2018'
      expect(subject['isbn']).to eq ['123456']
      expect(subject['issn']).to eq ['12345']
      expect(subject['journal_issue']).to eq '27'
      expect(subject['journal_title']).to eq 'Journal Title'
      expect(subject['journal_volume']).to eq '4'
      expect(subject['kind_of_data']).to eq 'a data type'
      expect(subject['last_modified_date']).to eq 'hi'
      expect(subject['medium']).to eq ['a medium']
      expect(subject['methodology']).to eq 'My methodology'
      expect(subject['note']).to eq ['a note']
      expect(subject['page_end']).to eq '11'
      expect(subject['page_start']).to eq '8'
      expect(subject['peer_review_status']).to eq 'in review'
      expect(subject['place_of_publication']).to eq ['durham']
      expect(subject['rights_holder']).to eq ['dean']
      expect(subject['series']).to eq ['series']
      expect(subject['sponsor']).to eq ['a sponsor']
      expect(subject['table_of_contents']).to eq ['cool table']
      expect(subject['use']).to eq ['a use']
      expect(subject['language_label']).to eq ['English']
      expect(subject['license_label']).to eq ['Attribution 3.0 United States']
      expect(subject['rights_statement_label']).to eq 'In Copyright'
    end

    context '.model_attributes' do
      let(:params) do
        ActionController::Parameters.new(
            title: '',
            description: '',
            keyword: [''],
            license: '',
            member_of_collection_ids: [''],
            on_behalf_of: 'Melissa'
        )
      end

      it 'removes blank parameters' do
        expect(subject['title']).to be_nil
        expect(subject['description']).to be_nil
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
