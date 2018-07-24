# Generated via
#  `rails generate hyrax:work General`
require 'rails_helper'

RSpec.describe Hyrax::GeneralForm do
  let(:work) { General.new }
  let(:form) { described_class.new(work, nil, nil) }

  describe "#required_fields" do
    subject { form.required_fields }

    it { is_expected.to eq [:title] }
  end

  describe "#primary_terms" do
    subject { form.primary_terms }

    it { is_expected.to eq [:title] }
  end

  describe "#secondary_terms" do
    subject { form.secondary_terms }

    it { is_expected.to match_array [:contributor, :creator, :date_created, :description, :deposit_record, :keyword,
                                     :identifier, :language, :license, :publisher, :related_url, :resource_type, :rights_statement,
                                     :subject, :bibliographic_citation, :abstract, :academic_concentration, :access,
                                     :advisor, :alternative_title, :arranger, :award, :composer, :conference_name,
                                     :copyright_date, :date_captured, :date_issued, :date_other, :degree,
                                     :degree_granting_institution, :discipline, :doi, :edition,
                                     :extent, :funder, :genre, :geographic_subject, :graduation_year, :isbn, :issn,
                                     :journal_issue, :journal_title, :journal_volume, :kind_of_data,
                                     :last_modified_date, :medium, :note, :page_start, :page_end, :peer_review_status,
                                     :place_of_publication, :project_director, :researcher, :reviewer, :rights_holder,
                                     :series, :sponsor, :table_of_contents, :translator, :url, :use] }
  end

  describe '.model_attributes' do
    let(:params) do
      ActionController::Parameters.new(
          title: 'foo', # single-valued
          bibliographic_citation: ['a citation'],
          contributor: ['a contributor'],
          creator: ['a creator'],
          date_created: ['2017-01-22'],
          deposit_record: 'uuid:1234',
          identifier: ['an identifier'],
          language: ['a language'],
          license: 'http://creativecommons.org/licenses/by/3.0/us/', # single-valued
          keyword: ['derp'],
          publisher: ['a publisher'],
          related_url: ['a url'],
          resource_type: ['a type'],
          rights_statement: 'a statement', # single-valued
          subject: ['a subject'],
          description: [''],
          visibility: 'open',
          representative_id: '456',
          thumbnail_id: '789',
          member_of_collection_ids: ['123456', 'abcdef'],
          abstract: ['an abstract'],
          academic_concentration: ['a concentration'],
          access: 'public', # single-valued
          advisor: ['an advisor'],
          alternative_title: ['some title'],
          arranger: ['an arranger'],
          award: ['an award'],
          composer: ['a composer'],
          conference_name: ['a conference'],
          copyright_date: ['2017-01-22'],
          date_captured: '2017-01-22', # single-valued
          date_issued: ['2017-01-22'],
          date_other: ['2017-01-22'],
          degree: 'something', # single-valued
          degree_granting_institution: 'unc', # single-valued
          digital_collection: ['a collection'],
          discipline: ['a discipline'],
          doi: '12345', # single-valued
          edition: ['an edition'],
          extent: ['1993'],
          funder: ['dean'],
          genre: ['a genre'],
          geographic_subject: ['California'],
          graduation_year: '2018', # single-valued
          isbn: ['123456'],
          issn: ['12345'],
          journal_issue: '27', # single-valued
          journal_title: 'Journal Title', # single-valued
          journal_volume: '4', # single-valued
          kind_of_data: ['a data type'],
          last_modified_date: 'hi', # single-valued
          medium: ['a medium'],
          note: ['a note'],
          page_end: '11', # single-valued
          page_start: '8', # single-valued
          peer_review_status: 'in review', # single-valued
          place_of_publication: ['durham'],
          project_director: ['someone'],
          researcher: ['a researcher'],
          reviewer: ['a reviewer'],
          rights_holder: ['dean'],
          series: ['series'],
          sponsor: ['a sponsor'],
          table_of_contents: ['cool table'],
          translator: ['dean'],
          url: ['http://unc.edu'],
          use: ['a use']
      )
    end

    subject { described_class.model_attributes(params) }

    it 'permits parameters' do
      expect(subject['title']).to eq ['foo']
      expect(subject['bibliographic_citation']).to eq ['a citation']
      expect(subject['contributor']).to eq ['a contributor']
      expect(subject['date_created']).to eq ['2017-01-22']
      expect(subject['deposit_record']).to eq 'uuid:1234'
      expect(subject['identifier']).to eq ['an identifier']
      expect(subject['language']).to eq ['a language']
      expect(subject['publisher']).to eq ['a publisher']
      expect(subject['related_url']).to eq ['a url']
      expect(subject['resource_type']).to eq ['a type']
      expect(subject['rights_statement']).to eq ['a statement']
      expect(subject['subject']).to eq ['a subject']
      expect(subject['description']).to be_empty
      expect(subject['visibility']).to eq 'open'
      expect(subject['license']).to eq ['http://creativecommons.org/licenses/by/3.0/us/']
      expect(subject['keyword']).to eq ['derp']
      expect(subject['member_of_collection_ids']).to eq ['123456', 'abcdef']
      expect(subject['abstract']).to eq ['an abstract']
      expect(subject['academic_concentration']).to eq ['a concentration']
      expect(subject['access']).to eq 'public'
      expect(subject['advisor']).to eq ['an advisor']
      expect(subject['alternative_title']).to eq ['some title']
      expect(subject['arranger']).to eq ['an arranger']
      expect(subject['award']).to eq ['an award']
      expect(subject['composer']).to eq ['a composer']
      expect(subject['conference_name']).to eq ['a conference']
      expect(subject['copyright_date']).to eq ['2017-01-22']
      expect(subject['date_captured']).to eq '2017-01-22'
      expect(subject['date_issued']).to eq ['2017-01-22']
      expect(subject['date_other']).to eq ['2017-01-22']
      expect(subject['degree']).to eq 'something'
      expect(subject['degree_granting_institution']).to eq 'unc'
      expect(subject['digital_collection']).to be_nil
      expect(subject['discipline']).to eq ['a discipline']
      expect(subject['doi']).to eq '12345'
      expect(subject['edition']).to eq ['an edition']
      expect(subject['extent']).to eq ['1993']
      expect(subject['funder']).to eq ['dean']
      expect(subject['genre']).to eq ['a genre']
      expect(subject['geographic_subject']).to eq ['California']
      expect(subject['graduation_year']).to eq '2018'
      expect(subject['isbn']).to eq ['123456']
      expect(subject['issn']).to eq ['12345']
      expect(subject['journal_issue']).to eq '27'
      expect(subject['journal_title']).to eq 'Journal Title'
      expect(subject['journal_volume']).to eq '4'
      expect(subject['kind_of_data']).to eq ['a data type']
      expect(subject['last_modified_date']).to eq 'hi'
      expect(subject['medium']).to eq ['a medium']
      expect(subject['note']).to eq ['a note']
      expect(subject['page_end']).to eq '11'
      expect(subject['page_start']).to eq '8'
      expect(subject['peer_review_status']).to eq 'in review'
      expect(subject['place_of_publication']).to eq ['durham']
      expect(subject['project_director']).to eq ['someone']
      expect(subject['researcher']).to eq ['a researcher']
      expect(subject['reviewer']).to eq ['a reviewer']
      expect(subject['rights_holder']).to eq ['dean']
      expect(subject['series']).to eq ['series']
      expect(subject['sponsor']).to eq ['a sponsor']
      expect(subject['table_of_contents']).to eq ['cool table']
      expect(subject['translator']).to eq ['dean']
      expect(subject['url']).to eq ['http://unc.edu']
      expect(subject['use']).to eq ['a use']
    end

    context '.model_attributes' do
      let(:params) do
        ActionController::Parameters.new(
            title: '',
            description: [''],
            keyword: [''],
            license: '',
            member_of_collection_ids: [''],
            on_behalf_of: 'Melissa'
        )
      end

      it 'removes blank parameters' do
        expect(subject['title']).to be_nil
        expect(subject['description']).to be_empty
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
