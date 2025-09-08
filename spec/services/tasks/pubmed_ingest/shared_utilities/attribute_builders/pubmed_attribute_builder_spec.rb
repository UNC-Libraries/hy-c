# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::PubmedIngest::SharedUtilities::AttributeBuilders::PubmedAttributeBuilder, type: :model do
  let(:admin_set) { FactoryBot.create(:admin_set) }
  let(:depositor) { FactoryBot.create(:admin, uid: 'admin') }
  let(:skipped_rows) do
    [
      { 'pmid' => '12345678', 'pmcid' => 'PMC11111111' },
      { 'pmid' => '99999999', 'pmcid' => 'PMC87654321' }
    ]
  end
  let(:metadata_doc) { Nokogiri::XML(File.read(Rails.root.join('spec/fixtures/files/pubmed_api_response_multi.xml'))) }
  let(:article_node) { metadata_doc.xpath('//PubmedArticle').first }
  let(:article) { Article.new }
  let(:builder) { described_class.new(article_node, article, admin_set, depositor.uid) }

  describe '#find_skipped_row' do
    it 'matches by pmid' do
      allow(article_node).to receive(:at_xpath)
        .with('PubmedData/ArticleIdList/ArticleId[@IdType="pubmed"]')
        .and_return(double(text: '12345678'))
      allow(article_node).to receive(:at_xpath)
        .with('PubmedData/ArticleIdList/ArticleId[@IdType="pmc"]')
        .and_return(nil)

      result = builder.find_skipped_row(skipped_rows)
      expect(result['pmid']).to eq('12345678')
    end

    it 'matches by pmcid' do
      allow(article_node).to receive(:at_xpath)
        .with('PubmedData/ArticleIdList/ArticleId[@IdType="pubmed"]')
        .and_return(nil)
      allow(article_node).to receive(:at_xpath)
        .with('PubmedData/ArticleIdList/ArticleId[@IdType="pmc"]')
        .and_return(double(text: 'PMC87654321'))

      result = builder.find_skipped_row(skipped_rows)
      expect(result['pmcid']).to eq('PMC87654321')
    end
  end

  describe '#generate_authors' do
    it 'returns authors with name, orcid, and other_affiliation' do
      authors = builder.send(:generate_authors)
      expect(authors).to all(include('name', 'orcid', 'index', 'other_affiliation'))
      expect(authors.first['name']).to match(/.+, .+/)
    end
  end

  describe '#set_identifiers' do
    it 'sets identifier and issn on the article' do
      builder.send(:set_identifiers)
      expect(article.identifier).to include(a_string_matching(/^PMID:/))
      expect(article.identifier).to include(a_string_matching(/^PMCID:/)).or be_present
      expect(article.identifier).to include(a_string_matching(/^DOI:/)).or be_present
      expect(article.issn).to all(be_a(String))
    end
  end

  describe '#set_journal_attributes' do
    it 'sets journal-related fields on the article' do
      allow(article_node).to receive(:at_xpath).and_call_original
      allow(article_node).to receive(:at_xpath).with('MedlineCitation/Article/Pagination/StartPage').and_return(double('Nokogiri::XML::Node', text: '1'))
      allow(article_node).to receive(:at_xpath).with('MedlineCitation/Article/Pagination/EndPage').and_return(double('Nokogiri::XML::Node', text: '100'))
      allow(article_node).to receive(:at_xpath).with('MedlineCitation/Article/Journal/JournalIssue/Volume').and_return(double('Nokogiri::XML::Node', text: '10'))
      allow(article_node).to receive(:at_xpath).with('MedlineCitation/Article/Journal/JournalIssue/Issue').and_return(double('Nokogiri::XML::Node', text: '2'))
      allow(article_node).to receive(:at_xpath).with('MedlineCitation/Article/Journal/Title').and_return(double('Nokogiri::XML::Node', text: 'Journal of Testing'))
      builder.send(:set_journal_attributes)
      expect(article.journal_title).to be_present
      expect(article.journal_volume).to be_present
      expect(article.journal_issue).to be_present
      expect(article.page_start).to be_present
      expect(article.page_end).to be_present
    end
  end

  describe '#apply_additional_basic_attributes' do
    it 'sets core descriptive fields on the article' do
      builder.send(:apply_additional_basic_attributes)
      expect(article.title).to be_present
      expect(article.abstract).to be_present
      expect(article.date_issued).to match(/\d{4}-\d{2}-\d{2}/)
      expect(article.publisher).to eq([])
      expect(article.keyword).to all(be_a(String))
      expect(article.funder).to all(be_a(String))
    end

    it 'handles missing abstract gracefully' do
      allow(article_node).to receive(:xpath).and_call_original
      allow(article_node).to receive(:xpath)
        .with('MedlineCitation/Article/Abstract/AbstractText')
        .and_return(double('Nokogiri::XML::Node', text: ''))
      builder.send(:apply_additional_basic_attributes)
      expect(article.abstract).to eq(['N/A'])
    end
  end
end
