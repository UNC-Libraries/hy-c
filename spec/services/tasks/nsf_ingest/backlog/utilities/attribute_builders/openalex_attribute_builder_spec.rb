# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::NsfIngest::Backlog::Utilities::AttributeBuilders::OpenalexAttributeBuilder, type: :service do
  let(:admin_set) { double('AdminSet') }
  let(:depositor) { 'test-depositor' }
  let(:article) { Article.new }
  let(:config) { { 'depositor_onyen' => depositor } }

  let(:metadata) do
    {
      'title' => 'Sample OpenAlex Article',
      'publication_date' => '2024-03-01',
      'openalex_abstract' => 'An inverted abstract.',
      'openalex_keywords' => ['OpenAlex', 'Keyword'],
      'doi' => '10.1234/test.doi',
      'primary_location' => {
        'source' => {
          'display_name' => 'Journal of Test Studies',
          'host_organization_name' => 'Test Org',
          'issn_l' => '1234-5678'
        }
      },
      'grants' => [
        { 'funder_display_name' => 'NSF' },
        { 'funder_display_name' => 'DOE' }
      ],
      'biblio' => {
        'volume' => '12',
        'issue' => '4',
        'first_page' => '100',
        'last_page' => '110'
      },
      'authorships' => [
        {
          'author' => {
            'display_name' => 'Ming Yang',
            'orcid' => nil,
            'institutions' => [{ 'display_name' => 'University of North Carolina at Chapel Hill' }]
          }
        },
        {
          'author' => {
            'display_name' => 'James H. Anderson',
            'orcid' => 'https://orcid.org/0000-0001-7138-939X',
            'institutions' => [{ 'display_name' => 'University of North Carolina' }]
          }
        }
      ]
    }
  end

  subject(:builder) { described_class.new(metadata, article, admin_set, depositor) }

  before do
    allow(AffiliationUtilsHelper).to receive(:is_unc_affiliation?).and_wrap_original do |_, aff|
      aff.include?('North Carolina')
    end
    allow(WorkUtilsHelper).to receive(:normalize_doi).and_return('10.1234/test.doi')
    allow(HTTParty).to receive(:get).and_return(double(code: 200, body: {
      hitCount: 1,
      resultList: { result: [{ 'pmid' => '12345', 'pmcid' => 'PMC67890' }] }
    }.to_json))
  end

  describe '#generate_authors' do
    it 'formats author names as "Last, First" and includes affiliations' do
      authors = builder.send(:generate_authors)

      expect(authors.size).to eq(2)

      first = authors.first
      expect(first['name']).to eq('Yang, Ming')
      expect(first['index']).to eq('0')
      expect(first['other_affiliation']).to include('North Carolina')

      second = authors.second
      expect(second['name']).to eq('Anderson, James H.')
      expect(second['index']).to eq('1')
      expect(second['orcid']).to eq('https://orcid.org/0000-0001-7138-939X')
    end
  end

  describe '#format_author_name' do
    it 'returns "Last, First" for simple names' do
      expect(builder.send(:format_author_name, 'Ming Yang')).to eq('Yang, Ming')
    end

    it 'returns "Last, First Middle" for multi-part names' do
      expect(builder.send(:format_author_name, 'James H. Anderson')).to eq('Anderson, James H.')
    end

    it 'returns unchanged for single-part names' do
      expect(builder.send(:format_author_name, 'Plato')).to eq('Plato')
    end

    it 'handles nil or blank input gracefully' do
      expect(builder.send(:format_author_name, nil)).to eq('')
      expect(builder.send(:format_author_name, '')).to eq('')
    end
  end

  describe '#apply_additional_basic_attributes' do
    it 'sets expected article attributes' do
      builder.send(:apply_additional_basic_attributes)
      expect(article.title).to eq(['Sample OpenAlex Article'])
      expect(article.abstract).to eq(['An inverted abstract.'])
      expect(article.date_issued).to eq('2024-03-01T00:00:00Z')
      expect(article.publisher).to eq(['Test Org'])
      expect(article.keyword).to eq(['OpenAlex', 'Keyword'])
      expect(article.funder).to match_array(['NSF', 'DOE'])
    end
  end

  describe '#set_identifiers' do
    it 'populates identifier and ISSN attributes' do
      builder.send(:set_identifiers)
      expect(article.identifier).to include('PMID: 12345', 'PMCID: PMC67890', 'DOI: https://dx.doi.org/10.1234/test.doi')
      expect(article.issn).to eq(['1234-5678'])
    end
  end

  describe '#set_journal_attributes' do
    it 'assigns correct journal and page metadata' do
      builder.send(:set_journal_attributes)
      expect(article.journal_title).to eq('Journal of Test Studies')
      expect(article.journal_volume).to eq('12')
      expect(article.journal_issue).to eq('4')
      expect(article.page_start).to eq('100')
      expect(article.page_end).to eq('110')
    end
  end
end
