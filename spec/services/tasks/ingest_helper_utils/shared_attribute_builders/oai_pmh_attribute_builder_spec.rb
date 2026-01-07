# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::IngestHelperUtils::SharedAttributeBuilders::OaiPmhAttributeBuilder, type: :model do
  let(:admin_set) { FactoryBot.create(:admin_set) }
  let(:depositor) { FactoryBot.create(:admin, uid: 'admin') }
  let(:metadata) do
    {
      'cdc_id' => '140512',
      'title' => '2023 year in review : Preventing chronic disease',
      'abstract' => 'Preventing Chronic Disease (PCD) is pleased to release its 2023 Year in Review.',
      'date_issued' => '2023-01-01',
      'authors' => [
        { 'name' => 'Centers for Disease Control and Prevention (U.S.)', 'index' => '0' }
      ]
    }
  end
  let(:article) { Article.new }
  let(:builder) { described_class.new(metadata, admin_set, depositor.uid) }

  describe '#initialize' do
    it 'sets metadata, admin_set, and depositor_onyen' do
      expect(builder.metadata).to eq(metadata)
      expect(builder.admin_set).to eq(admin_set)
      expect(builder.depositor_onyen).to eq(depositor.uid)
    end
  end

  describe '#populate_article_metadata' do
    before do
      allow(CdrRightsStatementsService).to receive(:label).and_return('In Copyright')
    end

    it 'raises error if article is nil' do
      expect { builder.populate_article_metadata(nil) }.to raise_error(ArgumentError, 'Article cannot be nil')
    end

    it 'populates all article attributes' do
      builder.populate_article_metadata(article)

      expect(article.title).to eq(['2023 year in review : Preventing chronic disease'])
      expect(article.abstract).to eq(['Preventing Chronic Disease (PCD) is pleased to release its 2023 Year in Review.'])
      expect(article.date_issued).to eq('2023-01-01')
      expect(article.admin_set).to eq(admin_set)
      expect(article.depositor).to eq(depositor.uid)
      expect(article.resource_type).to eq(['Article'])
    end

    it 'sets rights statement and label' do
      builder.populate_article_metadata(article)

      expect(article.rights_statement).to eq('http://rightsstatements.org/vocab/InC/1.0/')
      expect(article.rights_statement_label).to eq('In Copyright')
      expect(article.dcmi_type).to eq(['http://purl.org/dc/dcmitype/Text'])
    end

    it 'handles HTML entities in title' do
      metadata['title'] = '2023 year in review &#8217; Preventing chronic disease'
      builder.populate_article_metadata(article)

      expect(article.title).to eq(['2023 year in review ’ Preventing chronic disease'])
    end

    it 'returns the article' do
      result = builder.populate_article_metadata(article)
      expect(result).to eq(article)
    end
  end

  describe '#apply_additional_basic_attributes' do
    it 'sets title, abstract, and date_issued' do
      builder.send(:apply_additional_basic_attributes, article)

      expect(article.title).to eq(['2023 year in review : Preventing chronic disease'])
      expect(article.abstract).to eq(['Preventing Chronic Disease (PCD) is pleased to release its 2023 Year in Review.'])
      expect(article.date_issued).to eq('2023-01-01')
    end

    it 'sets empty arrays for publisher, funder, and keyword' do
      builder.send(:apply_additional_basic_attributes, article)

      expect(article.publisher).to eq([])
      expect(article.funder).to eq([])
      expect(article.keyword).to eq([])
    end

    it 'handles missing title gracefully' do
      metadata.delete('title')
      builder.send(:apply_additional_basic_attributes, article)

      expect(article.title).to be_empty
    end

    it 'handles missing abstract gracefully' do
      metadata.delete('abstract')
      builder.send(:apply_additional_basic_attributes, article)

      expect(article.abstract).to be_empty
    end

    it 'unescapes HTML entities in title' do
      metadata['title'] = 'Testing &amp; Development &#8212; A Guide'
      builder.send(:apply_additional_basic_attributes, article)

      expect(article.title).to eq(['Testing & Development — A Guide'])
    end
  end

  describe '#generate_authors' do
    it 'returns authors from metadata' do
      authors = builder.send(:generate_authors)

      expect(authors).to eq([
        { 'name' => 'Centers for Disease Control and Prevention (U.S.)', 'index' => '0' }
      ])
    end

    it 'returns UNC as default when authors not present' do
      metadata.delete('authors')
      authors = builder.send(:generate_authors)

      expect(authors).to eq([
        { 'name' => 'The University of North Carolina at Chapel Hill', 'index' => '0' }
      ])
    end

    it 'returns UNC as default when authors is empty array' do
      metadata['authors'] = []
      authors = builder.send(:generate_authors)

      expect(authors).to eq([
        { 'name' => 'The University of North Carolina at Chapel Hill', 'index' => '0' }
      ])
    end

    it 'handles multiple authors' do
      metadata['authors'] = [
        { 'name' => 'Smith, John', 'index' => '0' },
        { 'name' => 'Doe, Jane', 'index' => '1' }
      ]
      authors = builder.send(:generate_authors)

      expect(authors).to eq(metadata['authors'])
    end
  end

  describe '#set_identifiers' do
    it 'returns empty array (intentionally unimplemented)' do
      result = builder.send(:set_identifiers, article)
      expect(result).to eq([])
    end
  end

  describe '#set_journal_attributes' do
    it 'does nothing (intentionally unimplemented)' do
      expect { builder.send(:set_journal_attributes, article) }.not_to raise_error
    end
  end

  describe '#retrieve_author_affiliations' do
    it 'does nothing (intentionally unimplemented)' do
      hash = {}
      author = double('author')
      expect { builder.send(:retrieve_author_affiliations, hash, author) }.not_to raise_error
    end
  end

  describe '#format_publication_identifiers' do
    it 'does nothing (intentionally unimplemented)' do
      expect { builder.send(:format_publication_identifiers) }.not_to raise_error
    end
  end

  describe 'integration with BaseAttributeBuilder' do
    before do
      allow(CdrRightsStatementsService).to receive(:label).and_return('In Copyright')
    end

    it 'inherits and uses base methods correctly' do
      builder.populate_article_metadata(article)

      # Verify base attributes set
      expect(article.admin_set).to eq(admin_set)
      expect(article.depositor).to eq(depositor.uid)
      expect(article.resource_type).to eq(['Article'])
      expect(article.rights_statement).to be_present
      expect(article.dcmi_type).to eq(['http://purl.org/dc/dcmitype/Text'])

      # Verify OAI-PMH specific attributes
      expect(article.title).to be_present
      expect(article.abstract).to be_present
      expect(article.date_issued).to be_present
    end
  end
end
