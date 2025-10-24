# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::NsfIngest::Backlog::Utilities::AttributeBuilders::OpenalexAttributeBuilder do
  let(:admin_set) { double('AdminSet') }
  let(:depositor) { 'test-depositor' }
  let(:article) { Article.new }
  let(:config) { { 'depositor_onyen' => depositor } }

  let(:metadata) do
    {
      'title' => 'Sample OpenAlex Article',
      'publication_date' => '2024-03-01',
      'openalex_abstract' => 'An inverted abstract.',
      'openalex_keywords' => ['AI', 'Machine Learning'],
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
            'display_name' => 'Alice Example',
            'orcid' => '0000-0001-1111-2222',
            'institutions' => [{ 'display_name' => 'University of North Carolina at Chapel Hill' }]
          }
        },
        {
          'author' => {
            'display_name' => 'Bob Example',
            'orcid' => nil,
            'institutions' => [{ 'display_name' => 'Duke University' }]
          }
        }
      ]
    }
  end

  subject(:builder) { described_class.new(metadata, article, admin_set, depositor) }

  before do
    # Stub helpers
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
    it 'builds author hashes with affiliations and indices' do
      authors = builder.send(:generate_authors)
      expect(authors.size).to eq(2)

      first = authors.first
      expect(first['name']).to eq('Alice Example')
      expect(first['orcid']).to eq('0000-0001-1111-2222')
      expect(first['index']).to eq('0')
      expect(first['other_affiliation']).to include('North Carolina')

      second = authors.second
      expect(second['name']).to eq('Bob Example')
      expect(second['orcid']).to be_nil
      expect(second['index']).to eq('1')
      expect(second['other_affiliation']).to eq('Duke University')
    end
  end

  describe '#apply_additional_basic_attributes' do
    it 'populates basic article fields correctly' do
      builder.send(:apply_additional_basic_attributes)

      expect(article.title).to eq(['Sample OpenAlex Article'])
      expect(article.abstract).to eq(['An inverted abstract.'])
      expect(article.date_issued).to eq('2024-03-01T00:00:00Z')
      expect(article.publisher).to eq(['Test Org'])
      expect(article.keyword).to eq(['AI', 'Machine Learning'])
      expect(article.funder).to match_array(['NSF', 'DOE'])
    end
  end

  describe '#set_identifiers' do
    it 'sets DOI, identifiers, and ISSN using helpers and remote data' do
      builder.send(:set_identifiers)

      expect(article.identifier).to include('PMID: 12345', 'PMCID: PMC67890', 'DOI: https://dx.doi.org/10.1234/test.doi')
      expect(article.issn).to eq(['1234-5678'])
    end
  end

  describe '#set_journal_attributes' do
    it 'applies journal metadata correctly' do
      builder.send(:set_journal_attributes)
      expect(article.journal_title).to eq('Journal of Test Studies')
      expect(article.journal_volume).to eq('12')
      expect(article.journal_issue).to eq('4')
      expect(article.page_start).to eq('100')
      expect(article.page_end).to eq('110')
    end
  end

  describe '#retrieve_alt_ids_from_europe_pmc' do
    it 'retrieves alternate IDs from API response' do
      pmid, pmcid = builder.send(:retrieve_alt_ids_from_europe_pmc, '10.1234/test.doi')
      expect(pmid).to eq('12345')
      expect(pmcid).to eq('PMC67890')
    end

    it 'returns nils on error response' do
      allow(HTTParty).to receive(:get).and_return(double(code: 404, body: '{}'))
      pmid, pmcid = builder.send(:retrieve_alt_ids_from_europe_pmc, '10.1234/test.doi')
      expect(pmid).to be_nil
      expect(pmcid).to be_nil
    end
  end
end
