# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::PubmedIngest::PubmedAttributeBuilder, type: :model do
  let(:builder) { described_class.new }
  let(:metadata_doc) { Nokogiri::XML(File.read(Rails.root.join('spec/fixtures/files/pubmed_api_response_multi.xml'))) }
  let(:article_node) { metadata_doc.xpath('//PubmedArticle').first }

  describe '#find_skipped_row' do
    let(:pmid) { '12345678' }
    let(:pmcid) { 'PMC87654321' }
    let(:skipped_works) do
      [
        { 'pmid' => pmid, 'pmcid' => 'PMC11111111' },
        { 'pmid' => '99999999', 'pmcid' => pmcid }
      ]
    end

    it 'finds by pmid' do
      allow(article_node).to receive(:at_xpath).with('PubmedData/ArticleIdList/ArticleId[@IdType="pubmed"]').and_return(double(text: pmid))
      allow(article_node).to receive(:at_xpath).with('PubmedData/ArticleIdList/ArticleId[@IdType="pmc"]').and_return(nil)
      row = builder.find_skipped_row(article_node, skipped_works)
      expect(row['pmid']).to eq(pmid)
    end

    it 'finds by pmcid' do
      allow(article_node).to receive(:at_xpath).with('PubmedData/ArticleIdList/ArticleId[@IdType="pubmed"]').and_return(nil)
      allow(article_node).to receive(:at_xpath).with('PubmedData/ArticleIdList/ArticleId[@IdType="pmc"]').and_return(double(text: pmcid))
      row = builder.find_skipped_row(article_node, skipped_works)
      expect(row['pmcid']).to eq(pmcid)
    end
  end

  describe '#get_date_issued' do
    it 'extracts the publication date from PubMedPubDate[@PubStatus="pubmed"]' do
      date = builder.get_date_issued(article_node)
      expect(date).to match(/\d{4}-\d{2}-\d{2}/)
    end
  end

  describe '#generate_authors' do
    it 'returns authors with name, orcid, and affiliation' do
      authors = builder.generate_authors(article_node)
      expect(authors).to all(include('name', 'orcid', 'index', 'other_affiliation'))
      expect(authors.first['name']).to match(/.+, .+/)
    end
  end

  describe '#set_identifiers' do
    let(:article) { Article.new }

    it 'sets article.identifier and issn' do
      builder.set_identifiers(article, article_node)
      expect(article.identifier).to include(a_string_matching(/^PMID:/))
      expect(article.identifier).to include(a_string_matching(/^PMCID:/)).or be_present
      expect(article.identifier).to include(a_string_matching(/^DOI:/)).or be_present
      expect(article.issn).to all(be_a(String))
    end
  end

  describe '#set_journal_attributes' do
    let(:article) { Article.new }

    it 'sets journal title, volume, issue, and pages' do
      allow(article_node).to receive(:at_xpath).and_call_original
      allow(article_node).to receive(:at_xpath).with('MedlineCitation/Article/Pagination/StartPage').and_return(double('Nokogiri::XML::Node', text: '1'))
      allow(article_node).to receive(:at_xpath).with('MedlineCitation/Article/Pagination/EndPage').and_return(double('Nokogiri::XML::Node', text: '100'))
      builder.set_journal_attributes(article, article_node)
      expect(article.journal_title).to be_present
      expect(article.journal_volume).to be_present
      expect(article.journal_issue).to be_present
      expect(article.page_start).to be_present
      expect(article.page_end).to be_present
    end
  end

  describe '#apply_additional_basic_attributes' do
    let(:article) { Article.new }

    it 'sets title, abstract, date_issued, keywords, funders, and leaves publisher blank' do
      builder.apply_additional_basic_attributes(article, article_node)
      expect(article.title).to be_present
      expect(article.abstract).to be_present
      expect(article.date_issued).to match(/\d{4}-\d{2}-\d{2}/)
      expect(article.publisher).to eq([])
      expect(article.keyword).to all(be_a(String))
      expect(article.funder).to all(be_a(String))
    end
  end
end
