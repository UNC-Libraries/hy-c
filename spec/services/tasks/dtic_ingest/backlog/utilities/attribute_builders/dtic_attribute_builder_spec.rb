# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::DTICIngest::Backlog::Utilities::AttributeBuilders::DTICAttributeBuilder do
  let(:admin_set) { FactoryBot.create(:admin_set, title: ['DTIC Admin Set']) }
  let(:depositor_onyen) { 'testuser' }
  let(:metadata) do
    {
      'filename' => 'AD1192590.pdf',
      'content_date' => 'Oct 3, 2022',
      'title' => 'Test Article Title',
      'subject' => 'Test abstract content',
      'author' => 'Blackburn, Troy;Smith,Jane',
      'url' => 'https://example.com/AD1192590.pdf'
    }
  end

  subject(:builder) do
    described_class.new(metadata, admin_set, depositor_onyen)
  end

  describe '#populate_article_metadata' do
    let(:article) { FactoryBot.build(:article) }

    before do
      builder.populate_article_metadata(article)
    end

    it 'sets title from metadata' do
      expect(article.title).to eq(['Test Article Title'])
    end

    it 'sets abstract from subject field' do
      expect(article.abstract).to eq(['Test abstract content'])
    end

    it 'sets abstract to N/A when subject is blank' do
      metadata['subject'] = ''
      builder = described_class.new(metadata, admin_set, depositor_onyen)
      article = FactoryBot.build(:article)

      builder.populate_article_metadata(article)

      expect(article.abstract).to eq(['N/A'])
    end

    it 'sets date_issued from content_date' do
      expect(article.date_issued).to eq('2022-10-03')
    end

    it 'handles missing content_date' do
      metadata['content_date'] = nil
      builder = described_class.new(metadata, admin_set, depositor_onyen)
      article = FactoryBot.build(:article)

      builder.populate_article_metadata(article)

      expect(article.date_issued).to be_nil
    end

    it 'sets DTIC ID as identifier' do
      expect(article.identifier).to include('DTIC ID: AD1192590')
    end

    it 'does not set identifier if filename has no numbers' do
      metadata['filename'] = 'report.pdf'
      builder = described_class.new(metadata, admin_set, depositor_onyen)
      article = FactoryBot.build(:article)

      builder.populate_article_metadata(article)

      expect(article.identifier).to be_empty
    end
  end

  describe 'author parsing' do
    let(:article) { FactoryBot.build(:article) }

    it 'parses multiple authors separated by semicolons' do
      builder.populate_article_metadata(article)

      expect(article.creators.size).to eq(2)
      expect(article.creators[0].name.first).to eq('Blackburn, Troy')
      expect(article.creators[0].index.first).to eq('0')
      expect(article.creators[1].name.first).to eq('Smith, Jane')
      expect(article.creators[1].index.first).to eq('1')
    end

    it 'normalizes author names with missing spaces after commas' do
      metadata['author'] = 'McCafferty,Dewey G.'
      builder = described_class.new(metadata, admin_set, depositor_onyen)
      article = FactoryBot.build(:article)

      builder.populate_article_metadata(article)

      expect(article.creators.size).to eq(1)
      expect(article.creators[0].name.first).to eq('McCafferty, Dewey G.')
    end

    it 'handles single author' do
      metadata['author'] = 'Smith, John'
      builder = described_class.new(metadata, admin_set, depositor_onyen)
      article = FactoryBot.build(:article)

      builder.populate_article_metadata(article)

      expect(article.creators.size).to eq(1)
      expect(article.creators[0].name.first).to eq('Smith, John')
    end

    it 'uses institutional author when author field is blank' do
      metadata['author'] = ''
      builder = described_class.new(metadata, admin_set, depositor_onyen)
      article = FactoryBot.build(:article)

      builder.populate_article_metadata(article)

      expect(article.creators.size).to eq(1)
      expect(article.creators[0].name.first).to eq('The University of North Carolina at Chapel Hill')
    end

    it 'uses institutional author when author field is nil' do
      metadata['author'] = nil
      builder = described_class.new(metadata, admin_set, depositor_onyen)
      article = FactoryBot.build(:article)

      builder.populate_article_metadata(article)

      expect(article.creators.size).to eq(1)
      expect(article.creators[0].name.first).to eq('The University of North Carolina at Chapel Hill')
    end

    it 'strips whitespace from author names' do
      metadata['author'] = ' Doe, Jane  ; Smith, Bob '
      builder = described_class.new(metadata, admin_set, depositor_onyen)
      article = FactoryBot.build(:article)

      builder.populate_article_metadata(article)

      expect(article.creators.size).to eq(2)
      expect(article.creators[0].name.first).to eq('Doe, Jane')
      expect(article.creators[1].name.first).to eq('Smith, Bob')
    end
  end

  describe 'date parsing' do
    let(:article) { FactoryBot.build(:article) }

    it 'parses various date formats' do
      test_cases = {
        'Oct 3, 2022' => '2022-10-03',
        'May 14, 2022' => '2022-05-14',
        'Dec 14, 2015' => '2015-12-14',
        'Jun 29, 1999' => '1999-06-29'
      }

      test_cases.each do |input, expected|
        metadata['content_date'] = input
        builder = described_class.new(metadata, admin_set, depositor_onyen)
        article = FactoryBot.build(:article)

        builder.populate_article_metadata(article)

        expect(article.date_issued).to eq(expected), "Failed for input: #{input}"
      end
    end

    it 'handles empty content_date gracefully' do
      metadata['content_date'] = ''
      builder = described_class.new(metadata, admin_set, depositor_onyen)
      article = FactoryBot.build(:article)

      builder.populate_article_metadata(article)

      expect(article.date_issued).to be_nil
    end
  end

  describe 'DTIC ID extraction' do
    let(:article) { FactoryBot.build(:article) }

    it 'extracts ID from various filename patterns' do
      test_cases = {
        'AD1192590.pdf' => 'AD1192590',
        'ADA383106.pdf' => 'ADA383106',
        'ADA202441.pdf' => 'ADA202441'
      }

      test_cases.each do |filename, expected_id|
        metadata['filename'] = filename
        builder = described_class.new(metadata, admin_set, depositor_onyen)
        article = FactoryBot.build(:article)

        builder.populate_article_metadata(article)

        expect(article.identifier).to include("DTIC ID: #{expected_id}")
      end
    end

    it 'does not set identifier for filenames without numbers' do
      metadata['filename'] = 'report.pdf'
      builder = described_class.new(metadata, admin_set, depositor_onyen)
      article = FactoryBot.build(:article)

      builder.populate_article_metadata(article)

      expect(article.identifier).to be_empty
    end
  end
end
