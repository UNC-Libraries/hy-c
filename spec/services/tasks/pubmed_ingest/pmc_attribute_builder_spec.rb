# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::PubmedIngest::PmcAttributeBuilder, type: :model do
  let(:builder) { described_class.new }
  let(:metadata) { Nokogiri::XML(File.read(Rails.root.join('spec/fixtures/files/pmc_api_response_multi.xml'))) }
  let(:article_node) { metadata.xpath('//article').first }

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
        # Mocking pmcid as nil and pmid to ensure correct behavior
      allow(metadata).to receive(:at_xpath).with('.//article-id[@pub-id-type="pmid"]').and_return(double(text: pmid))
      allow(metadata).to receive(:at_xpath).with('.//article-id[@pub-id-type="pmcid"]').and_return(nil)
      row = builder.find_skipped_row(metadata, skipped_works)
      expect(row['pmid']).to eq(pmid)
    end

    it 'finds by pmcid' do
        # Mocking pmid as nil and pmcid to ensure correct behavior
      allow(metadata).to receive(:at_xpath).with('.//article-id[@pub-id-type="pmid"]').and_return(nil)
      allow(metadata).to receive(:at_xpath).with('.//article-id[@pub-id-type="pmcid"]').and_return(double(text: pmcid))
      row = builder.find_skipped_row(metadata, skipped_works)
      expect(row['pmcid']).to eq(pmcid)
    end
  end

  describe '#get_date_issued' do
    it 'extracts the publication date from pub-date[@pub-type="epub"]' do
      date = builder.get_date_issued(metadata)
      puts "Extracted Date: #{date}"
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
      expect(article.identifier).to include(a_string_matching(/^PMID:/), a_string_matching(/^PMCID:/), a_string_matching(/^DOI:/))
      expect(article.issn).to all(be_a(String))
    end
  end

  describe '#set_journal_attributes' do
    let(:article) { Article.new }

    it 'sets journal title, volume, issue, and pages' do
    # Mocking fpage and lpage since they are not present in the fixture
      allow(article_node).to receive(:at_xpath).and_call_original
      allow(article_node).to receive(:at_xpath).with('front/article-meta/fpage').and_return(double('Nokogiri::XML::Node', text: '1'))
      allow(article_node).to receive(:at_xpath).with('front/article-meta/lpage').and_return(double('Nokogiri::XML::Node', text: '10'))
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

    it 'sets title, abstract, date_issued, publisher, keyword, funder' do
      builder.apply_additional_basic_attributes(article, article_node)
      expect(article.title).to be_present
      expect(article.abstract).to be_present
      expect(article.date_issued).to match(/\d{4}-\d{2}-\d{2}/)
      expect(article.publisher).to be_present
      expect(article.keyword).to be_present
      expect(article.funder).to all(be_a(String))
    end
  end
end
