# Generated via
#  `rails generate hyrax:work Article`
require 'rails_helper'

RSpec.describe Hyrax::ArticleForm do
  let(:work) { Article.new }
  let(:form) { described_class.new(work, nil, nil) }

  describe "#required_fields" do
    subject { form.required_fields }

    it { is_expected.to eq [:title, :creator, :rights_statement] }
  end

  describe "#primary_terms" do
    subject { form.primary_terms }

    it { is_expected.to eq [:title, :creator, :rights_statement] }
  end

  describe "#secondary_terms" do
    subject { form.secondary_terms }

    it { is_expected.to eq [:abstract, :access, :affiliation, :citation, :copyright_date, :date_captured,
                            :date_created, :date_issued, :date_other, :doi, :edition, :extent, :funder, :genre,
                            :geographic_subject, :issn, :journal_issue, :journal_title, :journal_volume, :note, :orcid,
                            :other_affiliation, :page_end, :page_start, :peer_review_status, :place_of_publication,
                            :rights_holder, :table_of_contents, :translator, :url, :use, :contributor,
                            :identifier, :subject, :publisher, :language, :keyword,
                            :license, :resource_type, :description, :subject, :source, :identifier] }
  end

  describe '.model_attributes' do
    let(:params) do
      ActionController::Parameters.new(
          title: 'foo', # single-valued
          publisher: 'a publisher', # single-valued
          description: [''],
          visibility: 'open',
          representative_id: '456',
          thumbnail_id: '789',
          keyword: ['derp'],
          license: ['http://creativecommons.org/licenses/by/3.0/us/'],
          member_of_collection_ids: ['123456', 'abcdef'],
          abstract: ['an abstract'],
          access: 'public',
          affiliation: ['unc'],
          citation: ['a citation'],
          copyright_date: '2017-01-22',
          date_captured: '2017-01-22',
          date_created: '2017-01-22',
          date_issued: '2017-01-22',
          date_other: ['2017-01-22'],
          doi: ['12345'],
          edition: ['an edition'],
          extent: ['1993'],
          funder: ['dean'],
          genre: ['science fiction'],
          geographic_subject: ['California'],
          issn: ['12345'],
          journal_issue: '27',
          journal_title: 'Journal Title',
          journal_volume: '4',
          note: ['a note'],
          orcid: ['12345'],
          other_affiliation: ['duke'],
          page_end: ['11'],
          page_start: ['8'],
          peer_review_status: 'in review',
          place_of_publication: ['durham'],
          rights_holder: ['dean'],
          table_of_contents: ['cool table'],
          translator: ['dean'],
          url: ['http://unc.edu'],
          use: ['a use']
      )
    end

    subject { described_class.model_attributes(params) }

    it 'permits parameters' do
      expect(subject['title']).to eq ['foo']
      expect(subject['publisher']).to eq ['a publisher']
      expect(subject['description']).to be_empty
      expect(subject['visibility']).to eq 'open'
      expect(subject['license']).to eq ['http://creativecommons.org/licenses/by/3.0/us/']
      expect(subject['keyword']).to eq ['derp']
      expect(subject['member_of_collection_ids']).to eq ['123456', 'abcdef']

      expect(subject['abstract']).to eq ['an abstract']
      expect(subject['access']).to eq 'public'
      expect(subject['affiliation']).to eq ['unc']
      expect(subject['citation']).to eq ['a citation']
      expect(subject['copyright_date']).to eq '2017-01-22'
      expect(subject['date_captured']).to eq '2017-01-22'
      expect(subject['date_created']).to eq '2017-01-22'
      expect(subject['date_issued']).to eq '2017-01-22'
      expect(subject['date_other']).to eq ['2017-01-22']
      expect(subject['doi']).to eq ['12345']
      expect(subject['edition']).to eq ['an edition']
      expect(subject['extent']).to eq ['1993']
      expect(subject['funder']).to eq 'dean'
      expect(subject['genre']).to eq 'science fiction'
      expect(subject['geographic_subject']).to eq ['California']
      expect(subject['issn']).to eq ['12345']
      expect(subject['journal_issue']).to eq '27'
      expect(subject['journal_title']).to eq 'Journal Title'
      expect(subject['journal_volume']).to eq '4'
      expect(subject['note']).to eq ['a note']
      expect(subject['orcid']).to eq ['orcid']
      expect(subject['other_affiliation']).to eq ['duke']
      expect(subject['page_end']).to eq '11'
      expect(subject['page_start']).to eq '8'
      expect(subject['peer_review_status']).to eq 'in review'
      expect(subject['place_of_publication']).to eq ['durham']
      expect(subject['rights_holder']).to eq ['dean']
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
            license: [''],
            member_of_collection_ids: [''],
            on_behalf_of: 'Melissa'
        )
      end

      it 'removes blank parameters' do
        expect(subject['title']).to be_empty
        expect(subject['description']).to be_empty
        expect(subject['license']).to be_empty
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
