# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::NASAIngest::Backlog::Utilities::AttributeBuilders::NASAAttributeBuilder do
  let(:admin_set) { FactoryBot.create(:admin_set) }
  let(:depositor) { FactoryBot.create(:user) }
  let(:article) { FactoryBot.build(:article) }
  let(:config) { { 'depositor_onyen' => depositor.uid } }

  let(:metadata) do
    {
      'id' => 20230015324,
      'title' => 'Using Regionalized Air Quality Model Performance',
      'abstract' => 'Test abstract content',
      'distributionDate' => '2023-10-13T04:00:00.0000000+00:00',
      'keywords' => ['Ozone', 'Data fusion'],
      'authorAffiliations' => [
        {
          'sequence' => 0,
          'meta' => {
            'author' => { 'name' => 'Jacob S. Becker' },
            'organization' => { 'name' => 'University of North Carolina at Chapel Hill' }
          }
        },
        {
          'sequence' => 1,
          'meta' => {
            'author' => { 'name' => 'Marissa N. DeLang' },
            'organization' => { 'name' => 'University of North Carolina at Chapel Hill' }
          }
        }
      ],
      'publications' => [
        {
          'publisher' => 'University of California Press',
          'eissn' => '2325-1026',
          'doi' => '10.1525/elementa.2022.00025',
          'publicationName' => 'Elementa Science of the Anthropocene',
          'volume' => '11'
        }
      ]
    }
  end

  subject(:builder) { described_class.new(metadata, admin_set, depositor.uid) }

  before do
    allow(Rails.logger).to receive(:warn)
    allow(Rails.logger).to receive(:error)
  end

  describe '#apply_additional_basic_attributes' do
    it 'assigns core article attributes from metadata' do
      builder.send(:apply_additional_basic_attributes, article)

      expect(article.title).to eq(['Using Regionalized Air Quality Model Performance'])
      expect(article.abstract).to eq(['Test abstract content'])
      expect(article.date_issued).to eq('2023-10-13')
      expect(article.publisher).to eq(['University of California Press'])
      expect(article.keyword).to eq(['Ozone', 'Data fusion'])
    end

    it 'uses N/A when abstract is missing' do
      metadata.delete('abstract')
      builder.send(:apply_additional_basic_attributes, article)

      expect(article.abstract).to eq(['N/A'])
    end

    it 'handles missing distribution date gracefully' do
      metadata.delete('distributionDate')
      builder.send(:apply_additional_basic_attributes, article)

      expect(article.date_issued).to be_nil
    end

    it 'handles missing keywords gracefully' do
      metadata.delete('keywords')
      builder.send(:apply_additional_basic_attributes, article)

      expect(article.keyword).to eq([])
    end

    it 'handles missing publisher gracefully' do
      metadata['publications'] = []
      builder.send(:apply_additional_basic_attributes, article)

      expect(article.publisher).to be_empty
    end
  end

  describe '#set_identifiers' do
    it 'builds NASA ID and DOI identifiers correctly' do
      builder.send(:set_identifiers, article)

      expect(article.identifier).to include('NASA ID: 20230015324')
      expect(article.identifier).to include('DOI: https://doi.org/10.1525/elementa.2022.00025')
      expect(article.issn).to eq(['2325-1026'])
    end

    it 'handles missing NASA ID gracefully' do
      metadata.delete('id')
      builder.send(:set_identifiers, article)

      expect(article.identifier).not_to include(a_string_matching(/NASA ID/))
    end

    it 'handles missing DOI gracefully' do
      metadata['publications'][0].delete('doi')
      builder.send(:set_identifiers, article)

      expect(article.identifier).to eq(['NASA ID: 20230015324'])
    end

    it 'handles missing ISSN gracefully' do
      metadata['publications'][0].delete('eissn')
      builder.send(:set_identifiers, article)

      expect(article.issn).to be_empty
    end

    it 'handles missing publications array gracefully' do
      metadata.delete('publications')
      builder.send(:set_identifiers, article)

      expect(article.identifier).to eq(['NASA ID: 20230015324'])
      expect(article.issn).to be_empty
    end
  end

  describe '#generate_authors' do
    it 'returns an array of author hashes with names and indices' do
      authors = builder.send(:generate_authors)

      expect(authors.length).to eq(2)
      expect(authors[0]['name']).to eq('Becker, Jacob S.')
      expect(authors[0]['index']).to eq('0')
      expect(authors[0]['other_affiliation']).to eq(['University of North Carolina at Chapel Hill'])
      expect(authors[1]['name']).to eq('DeLang, Marissa N.')
      expect(authors[1]['index']).to eq('1')
    end

    it 'sorts authors by sequence field' do
      metadata['authorAffiliations'][0]['sequence'] = 1
      metadata['authorAffiliations'][1]['sequence'] = 0

      authors = builder.send(:generate_authors)

      expect(authors[0]['name']).to eq('DeLang, Marissa N.')
      expect(authors[1]['name']).to eq('Becker, Jacob S.')
    end

    it 'returns default value if no authors are present' do
      metadata.delete('authorAffiliations')
      authors = builder.send(:generate_authors)

      expect(authors[0]).to eq({ 'name' => 'The University of North Carolina at Chapel Hill', 'index' => '0' })
    end

    it 'handles missing organization name gracefully' do
      metadata['authorAffiliations'][0]['meta'].delete('organization')
      authors = builder.send(:generate_authors)

      expect(authors[0]['other_affiliation']).to be_nil
    end
  end

  describe '#reformat_author_name' do
    it 'converts "First Last" to "Last, First"' do
      result = builder.send(:reformat_author_name, 'Jacob Becker')
      expect(result).to eq('Becker, Jacob')
    end

    it 'converts "First Middle Last" to "Last, First Middle"' do
      result = builder.send(:reformat_author_name, 'Jacob S. Becker')
      expect(result).to eq('Becker, Jacob S.')
    end

    it 'returns name as-is if already in Last, First format' do
      result = builder.send(:reformat_author_name, 'Becker, Jacob')
      expect(result).to eq('Becker, Jacob')
    end

    it 'returns name as-is if it has no spaces' do
      result = builder.send(:reformat_author_name, 'Becker')
      expect(result).to eq('Becker')
    end

    it 'handles nil name gracefully' do
      result = builder.send(:reformat_author_name, nil)
      expect(result).to be_nil
    end
  end

  describe '#normalize_doi' do
    it 'strips https://doi.org/ prefix from DOI' do
      doi = 'https://doi.org/10.1525/elementa.2022.00025'
      result = builder.send(:normalize_doi, doi)
      expect(result).to eq('10.1525/elementa.2022.00025')
    end

    it 'returns the same DOI if no prefix present' do
      doi = '10.1525/elementa.2022.00025'
      result = builder.send(:normalize_doi, doi)
      expect(result).to eq(doi)
    end

    it 'returns nil if DOI is nil' do
      result = builder.send(:normalize_doi, nil)
      expect(result).to be_nil
    end
  end

  describe '#retrieve_author_affiliations' do
    it 'sets other_affiliation from organization name' do
      hash = {}
      affiliation_data = metadata['authorAffiliations'][0]

      builder.send(:retrieve_author_affiliations, hash, affiliation_data)

      expect(hash['other_affiliation']).to eq(['University of North Carolina at Chapel Hill'])
    end

    it 'does not set other_affiliation if organization is missing' do
      hash = {}
      affiliation_data = { 'meta' => { 'author' => { 'name' => 'Test' } } }

      builder.send(:retrieve_author_affiliations, hash, affiliation_data)

      expect(hash['other_affiliation']).to be_nil
    end

    it 'handles nil affiliation_data gracefully' do
      hash = {}

      builder.send(:retrieve_author_affiliations, hash, nil)

      expect(hash['other_affiliation']).to be_nil
    end
  end

  describe '#set_journal_attributes' do
    it 'sets journal title and volume from publications' do
      builder.send(:set_journal_attributes, article)

      expect(article.journal_title).to eq('Elementa Science of the Anthropocene')
      expect(article.journal_volume).to eq('11')
    end

    it 'handles missing publications gracefully' do
      metadata['publications'] = []
      builder.send(:set_journal_attributes, article)

      expect(article.journal_title).to be_nil
      expect(article.journal_volume).to be_nil
    end

    it 'handles missing volume gracefully' do
      metadata['publications'][0].delete('volume')
      builder.send(:set_journal_attributes, article)

      expect(article.journal_title).to eq('Elementa Science of the Anthropocene')
      expect(article.journal_volume).to be_nil
    end
  end
end
