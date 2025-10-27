# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::NsfIngest::Backlog::Utilities::AttributeBuilders::CrossrefAttributeBuilder do
  let(:admin_set) { double('AdminSet') }
  let(:depositor) { 'test-user' }
  let(:article) { Article.new }
  let(:config) { { 'depositor_onyen' => depositor } }

  let(:metadata) do
    {
      'title' => ['Test Article from CrossRef'],
      'openalex_abstract' => 'Open abstract text here.',
      'DOI' => '10.5555/deeplearn.2025',
      'publisher' => 'IEEE Press',
      'indexed' => { 'date-time' => '2025-03-10T00:00:00Z' },
      'funder' => [{ 'name' => 'NSF' }, { 'name' => 'NASA' }],
      'openalex_keywords' => ['Python', 'Hyrax'],
      'author' => [
        {
          'family' => 'Smith',
          'given' => 'John D.',
          'ORCID' => 'https://orcid.org/0000-0001-1111-2222',
          'affiliation' => [{ 'name' => 'University of North Carolina' }]
        },
        {
          'family' => 'Doe',
          'given' => 'Jane',
          'ORCID' => nil,
          'affiliation' => [{ 'name' => 'Duke University' }]
        }
      ],
      'issn-type' => [
        { 'type' => 'print', 'value' => '1234-1111' },
        { 'type' => 'electronic', 'value' => '9876-2222' }
      ],
      'container-title' => ['Journal of Scientific Studies'],
      'journal-issue' => { 'issue' => '42' },
      'volume' => '10',
      'page' => '101-119'
    }
  end

  subject(:builder) { described_class.new(metadata, article, admin_set, depositor) }

  before do
    # Mock helpers
    allow(AffiliationUtilsHelper).to receive(:is_unc_affiliation?).and_wrap_original do |_, aff|
      aff.include?('North Carolina')
    end
    allow(HTTParty).to receive(:get).and_return(double(code: 200, body: {
      hitCount: 1,
      resultList: { result: [{ 'pmid' => '54321', 'pmcid' => 'PMC98765' }] }
    }.to_json))
    allow(Rails.logger).to receive(:warn)
    allow(Rails.logger).to receive(:error)
  end

  describe '#generate_authors' do
    it 'returns author hashes with formatted names and affiliations' do
      authors = builder.send(:generate_authors)
      expect(authors.size).to eq(2)

      first = authors.first
      expect(first['name']).to eq('Smith, John D.')
      expect(first['orcid']).to eq('https://orcid.org/0000-0001-1111-2222')
      expect(first['index']).to eq('0')
      expect(first['other_affiliation']).to include('North Carolina')

      second = authors.second
      expect(second['name']).to eq('Doe, Jane')
      expect(second['index']).to eq('1')
      expect(second['orcid']).to be_nil
      expect(second['other_affiliation']).to eq('Duke University')
    end
  end

  describe '#apply_additional_basic_attributes' do
    it 'assigns core article attributes from metadata' do
      builder.send(:apply_additional_basic_attributes)

      expect(article.title).to eq(['Test Article from CrossRef'])
      expect(article.abstract).to eq(['Open abstract text here.'])
      expect(article.date_issued).to eq('2025-03-10T00:00:00Z')
      expect(article.publisher).to eq(['IEEE Press'])
      expect(article.keyword).to eq(['UNC', 'Hyrax'])
      expect(article.funder).to match_array(['NSF', 'NASA'])
    end

    it 'falls back to datacite_abstract when openalex_abstract missing' do
      metadata.delete('openalex_abstract')
      metadata['datacite_abstract'] = 'Alt abstract text.'
      builder.send(:apply_additional_basic_attributes)
      expect(article.abstract).to eq(['Alt abstract text.'])
    end
  end

  describe '#set_identifiers' do
    it 'builds identifiers and ISSNs correctly' do
      builder.send(:set_identifiers)
      expect(article.identifier).to include('PMID: 54321', 'PMCID: PMC98765', 'DOI: https://dx.doi.org/10.5555/deeplearn.2025')
      expect(article.issn).to eq(['9876-2222']) # electronic preferred
    end

    it 'logs warning and uses print ISSN if no electronic ISSN exists' do
      metadata['issn-type'] = [{ 'type' => 'print', 'value' => '1234-1111' }]
      builder.send(:set_identifiers)
      expect(article.issn).to eq(['1234-1111'])
      expect(Rails.logger).to have_received(:warn)
    end

    it 'logs warning if no ISSNs exist at all' do
      metadata['issn-type'] = []
      builder.send(:set_identifiers)
      expect(article.issn).to eq([])
      expect(Rails.logger).to have_received(:warn)
    end
  end

  describe '#retrieve_alt_ids_from_europe_pmc' do
    it 'returns pmid and pmcid from successful API response' do
      pmid, pmcid = builder.send(:retrieve_alt_ids_from_europe_pmc, '10.5555/deeplearn.2025')
      expect(pmid).to eq('54321')
      expect(pmcid).to eq('PMC98765')
    end

    it 'returns nil values when API fails' do
      allow(HTTParty).to receive(:get).and_return(double(code: 404, body: '{}'))
      pmid, pmcid = builder.send(:retrieve_alt_ids_from_europe_pmc, '10.5555/deeplearn.2025')
      expect(pmid).to be_nil
      expect(pmcid).to be_nil
      expect(Rails.logger).to have_received(:error)
    end
  end

  describe '#set_journal_attributes' do
    it 'assigns journal, volume, issue, and page range' do
      builder.send(:set_journal_attributes)
      expect(article.journal_title).to eq('Journal of Scientific Studies')
      expect(article.journal_volume).to eq('10')
      expect(article.journal_issue).to eq('42')
      expect(article.page_start).to eq('101')
      expect(article.page_end).to eq('119')
    end

    it 'handles single-page values correctly' do
      metadata['page'] = '55'
      builder.send(:set_journal_attributes)
      expect(article.page_start).to eq('55')
      expect(article.page_end).to be_nil
    end
  end

  describe '#extract_page_range' do
    it 'splits pages into start and end values' do
      expect(builder.send(:extract_page_range, metadata)).to eq(%w[101 119])
    end

    it 'returns [nil, nil] when no pages exist' do
      expect(builder.send(:extract_page_range, {})).to eq([nil, nil])
    end
  end

  describe '#extract_journal_title' do
    it 'prefers container-title when present' do
      expect(builder.send(:extract_journal_title)).to eq('Journal of Scientific Studies')
    end

    it 'falls back to short-container-title' do
      metadata.delete('container-title')
      metadata['short-container-title'] = ['J. Neural Appl.']
      expect(builder.send(:extract_journal_title)).to eq('J. Neural Appl.')
    end
  end
end
