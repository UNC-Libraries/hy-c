# Generated via
#  `rails generate hyrax:work Article`
require 'rails_helper'

RSpec.describe Hyrax::ArticleForm do
  let(:work) { Article.new }
  let(:form) { described_class.new(work, nil, nil) }

  describe '#required_fields' do
    subject { form.required_fields }

    it { is_expected.to match_array [:title, :creator, :abstract, :date_issued] }
  end

  describe '#primary_terms' do
    subject { form.primary_terms }

    it { is_expected.to match_array [:title, :creator, :abstract, :date_issued] }
  end

  describe '#secondary_terms' do
    subject { form.secondary_terms }

    it {
      is_expected.to match_array [:based_near, :keyword, :license, :rights_statement, :publisher, :subject,
                                  :language, :identifier, :related_url, :resource_type, :access, :alternative_title,
                                  :bibliographic_citation, :copyright_date, :date_captured, :date_other, :dcmi_type,
                                  :doi, :digital_collection, :edition, :extent, :funder, :issn,
                                  :journal_title, :journal_volume, :journal_issue, :note, :page_end, :page_start,
                                  :peer_review_status, :place_of_publication, :rights_holder, :translator, :use,
                                  :language_label, :license_label, :rights_statement_label, :deposit_agreement,
                                  :agreement, :admin_note]
    }
  end

  describe '#admin_only_terms' do
    subject { form.admin_only_terms }

    it {
      is_expected.to match_array [:dcmi_type, :access, :bibliographic_citation, :copyright_date,
                                  :date_captured, :date_other, :digital_collection, :doi, :extent, :rights_holder,
                                  :translator, :identifier, :use, :admin_note]
    }
  end

  describe 'default value set' do
    subject { form }
    it 'dcmi type must have default values' do
      expect(form.model['dcmi_type']).to eq ['http://purl.org/dc/dcmitype/Text']
    end
    it 'language must have default values' do
      expect(form.model['language']).to eq ['http://id.loc.gov/vocabulary/iso639-2/eng']
    end
    it 'rights statement must have a default value' do
      expect(form.model['rights_statement']).to eq 'http://rightsstatements.org/vocab/InC/1.0/'
    end
  end

  describe '.model_attributes' do
    let(:params) do
      ActionController::Parameters.new(
        title: 'foo', # single-valued
        bibliographic_citation: ['a citation'],
        creators_attributes: { '0' => { name: 'creator',
                                        orcid: 'creator orcid',
                                        affiliation: 'Carolina Center for Genome Sciences',
                                        other_affiliation: 'another affiliation',
                                        index: 1 },
                               '1' => { name: 'creator2',
                                        orcid: 'creator2 orcid',
                                        affiliation: 'Department of Chemistry',
                                        other_affiliation: 'another affiliation',
                                        index: 2 } },
        language: ['http://id.loc.gov/vocabulary/iso639-2/eng'],
        based_near: ['California'],
        publisher: ['a publisher'],
        related_url: ['a url'],
        resource_type: ['a type'],
        rights_statement: 'http://rightsstatements.org/vocab/InC/1.0/', # single-valued
        subject: ['a subject'],
        visibility: 'open',
        representative_id: '456',
        thumbnail_id: '789',
        keyword: ['derp'],
        license: 'http://creativecommons.org/licenses/by/3.0/us/', # single-valued
        member_of_collection_ids: ['123456', 'abcdef'],
        abstract: ['an abstract'],
        access: 'public', # single-valued
        alternative_title: ['my other title'],
        copyright_date: '2017', # single-valued
        date_issued: '2017-01-22', # single-valued
        date_captured: '2017-01-20', # single-valued
        date_other: [''],
        dcmi_type: ['http://purl.org/dc/dcmitype/Text'],
        digital_collection: ['my collection'],
        doi: '12345', # single-valued
        edition: 'an edition', # single-valued
        extent: ['1993'],
        funder: ['dean'],
        issn: ['12345'],
        journal_issue: '27', # single-valued
        journal_title: 'Journal Title', # single-valued
        journal_volume: '4', # single-valued
        note: ['a note'],
        page_end: '11', # single-valued
        page_start: '8', # single-valued
        peer_review_status: 'in review', # single-valued
        place_of_publication: ['durham'],
        rights_holder: ['dean'],
        translators_attributes: { '0' => { name: 'translator',
                                           orcid: 'translator orcid',
                                           affiliation: 'Carolina Center for Genome Sciences',
                                           other_affiliation: 'another affiliation' } },
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
      expect(subject['language']).to eq ['http://id.loc.gov/vocabulary/iso639-2/eng']
      expect(subject['based_near']).to eq ['California']
      expect(subject['license']).to eq ['http://creativecommons.org/licenses/by/3.0/us/']
      expect(subject['publisher']).to eq ['a publisher']
      expect(subject['related_url']).to eq ['a url']
      expect(subject['resource_type']).to eq ['a type']
      expect(subject['rights_statement']).to eq 'http://rightsstatements.org/vocab/InC/1.0/'
      expect(subject['subject']).to eq ['a subject']
      expect(subject['visibility']).to eq 'open'
      expect(subject['license']).to eq ['http://creativecommons.org/licenses/by/3.0/us/']
      expect(subject['keyword']).to eq ['derp']
      expect(subject['member_of_collection_ids']).to eq ['123456', 'abcdef']
      expect(subject['abstract']).to eq ['an abstract']
      expect(subject['access']).to eq 'public'
      expect(subject['alternative_title']).to eq ['my other title']
      expect(subject['copyright_date']).to eq '2017'
      expect(subject['date_issued']).to eq '2017-01-22'
      expect(subject['date_captured']).to eq '2017-01-20'
      expect(subject['date_other']).to be_empty
      expect(subject['digital_collection']).to eq ['my collection']
      expect(subject['doi']).to eq '12345'
      expect(subject['edition']).to eq 'an edition'
      expect(subject['extent']).to eq ['1993']
      expect(subject['funder']).to eq ['dean']
      expect(subject['dcmi_type']).to eq ['http://purl.org/dc/dcmitype/Text']
      expect(subject['issn']).to eq ['12345']
      expect(subject['journal_issue']).to eq '27'
      expect(subject['journal_title']).to eq 'Journal Title'
      expect(subject['journal_volume']).to eq '4'
      expect(subject['note']).to eq ['a note']
      expect(subject['page_end']).to eq '11'
      expect(subject['page_start']).to eq '8'
      expect(subject['peer_review_status']).to eq 'in review'
      expect(subject['place_of_publication']).to eq ['durham']
      expect(subject['rights_holder']).to eq ['dean']
      expect(subject['use']).to eq ['a use']
      expect(subject['language_label']).to eq ['English']
      expect(subject['license_label']).to eq ['Attribution 3.0 United States']
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
      expect(subject['translators_attributes']['0']['name']).to eq 'translator'
      expect(subject['translators_attributes']['0']['orcid']).to eq 'translator orcid'
      expect(subject['translators_attributes']['0']['affiliation']).to eq 'Carolina Center for Genome Sciences'
      expect(subject['translators_attributes']['0']['other_affiliation']).to eq 'another affiliation'
      expect(subject['translators_attributes']['0']['index']).to eq 1
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
          creators_attributes: { '0' => { name: 'creator',
                                          orcid: 'creator orcid',
                                          affiliation: 'Carolina Center for Genome Sciences',
                                          other_affiliation: 'another affiliation',
                                          index: 2 },
                                 '1' => { name: 'creator2',
                                          orcid: 'creator2 orcid',
                                          affiliation: 'Department of Chemistry',
                                          other_affiliation: 'another affiliation',
                                          index: 1 },
                                 '2' => { name: 'creator3',
                                          orcid: 'creator3 orcid',
                                          affiliation: 'Department of Chemistry',
                                          other_affiliation: 'another affiliation' } },
          translators_attributes: { '0' => { name: 'translator',
                                             orcid: 'translator orcid',
                                             affiliation: 'Carolina Center for Genome Sciences',
                                             other_affiliation: 'another affiliation' },
                                    '1' => { name: 'translator2',
                                             orcid: 'translator2 orcid',
                                             affiliation: 'Department of Chemistry',
                                             other_affiliation: 'another affiliation' } }
        )
      end

      it 'retains existing index values and adds missing index values' do
        expect(subject['creators_attributes'].as_json).to include({ '0' => { 'name' => 'creator',
                                                                             'orcid' => 'creator orcid',
                                                                             'affiliation' => 'Carolina Center for Genome Sciences',
                                                                             'other_affiliation' => 'another affiliation',
                                                                             'index' => 2 },
                                                                    '1' => { 'name' => 'creator2',
                                                                             'orcid' => 'creator2 orcid',
                                                                             'affiliation' => 'Department of Chemistry',
                                                                             'other_affiliation' => 'another affiliation',
                                                                             'index' => 1 },
                                                                    '2' => { 'name' => 'creator3',
                                                                             'orcid' => 'creator3 orcid',
                                                                             'affiliation' => 'Department of Chemistry',
                                                                             'other_affiliation' => 'another affiliation',
                                                                             'index' => 3 } })
        expect(subject['translators_attributes'].as_json).to include({ '0' => { 'name' => 'translator',
                                                                                'orcid' => 'translator orcid',
                                                                                'affiliation' => 'Carolina Center for Genome Sciences',
                                                                                'other_affiliation' => 'another affiliation',
                                                                                'index' => 1 },
                                                                       '1' => { 'name' => 'translator2',
                                                                                'orcid' => 'translator2 orcid',
                                                                                'affiliation' => 'Department of Chemistry',
                                                                                'other_affiliation' => 'another affiliation',
                                                                                'index' => 2 } })
      end
    end
  end

  describe '#visibility' do
    subject { form.visibility }

    it { is_expected.to eq 'restricted' }
  end

  describe '#agreement_accepted' do
    subject { form.agreement_accepted }

    it { is_expected.to eq false }
  end

  context 'on a work already saved' do
    before { allow(work).to receive(:new_record?).and_return(false) }
    it 'defaults deposit agreement to true' do
      expect(form.agreement_accepted).to eq(true)
    end
  end
end
