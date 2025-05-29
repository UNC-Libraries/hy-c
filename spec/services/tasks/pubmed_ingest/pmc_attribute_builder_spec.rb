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
      allow(metadata).to receive(:at_xpath).with('.//article-id[@pub-id-type="pmid"]').and_return(double(text: pmid))
      allow(metadata).to receive(:at_xpath).with('.//article-id[@pub-id-type="pmcid"]').and_return(nil)
      row = builder.find_skipped_row(metadata, skipped_works)
      expect(row['pmid']).to eq(pmid)
    end

    it 'finds by pmcid' do
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
      puts "Article Identifiers: #{article.identifier.inspect}"
      expect(article.issn).to all(be_a(String))
      puts "Article ISSN: #{article.issn.inspect}"
    end
  end

  describe '#set_journal_attributes' do
    let(:article) { Article.new }

    it 'sets journal title, volume, issue, and pages' do
    # Mocking fpage and lpage since they are not present in the fixture
      allow(article_node).to receive(:at_xpath).with('front/article-meta/fpage').and_return(double('Nokogiri::XML::Node', text: '1'))
      allow(article_node).to receive(:at_xpath).with('front/article-meta/lpage').and_return(double('Nokogiri::XML::Node', text: '10'))
      allow(article_node).to receive(:at_xpath).with('front/journal-meta/journal-title-group/journal-title').and_call_original
      allow(article_node).to receive(:at_xpath).with('front/article-meta/volume').and_call_original
      allow(article_node).to receive(:at_xpath).with('front/article-meta/issue-id').and_call_original
      builder.set_journal_attributes(article, article_node)
      puts "Journal Title: #{article.journal_title} Journal Volume: #{article.journal_volume} Journal Issue: #{article.journal_issue} Page Start: #{article.page_start} Page End: #{article.page_end}"
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
      expect(article.title).to eq(['The Unified Phenotype Ontology : a framework for cross-species integrative phenomics'])
      expect(article.abstract.first).to include(
        'Phenotypic data are critical for understanding biological mechanisms and' +
        ' consequences of genomic variation, and are pivotal for clinical use cases such as disease diagnostics and treatment development. For over a century, vast quantities' +
        ' of phenotype data have been collected in many different contexts covering a variety of organisms. The emerging field of phenomics focuses on integrating and interpreting'
        )
      expect(article.date_issued).to eq('2025-03-06')
      expect(article.publisher).to eq(['Oxford University Press'])
      expect(article.keyword).to eq(['phenotype', 'ontology', 'integration', 'semantics', 'Hispanic/Latinas', 'miscarriage', 'pregnancy loss', 'acculturation', 'intimate partner violence', 'sociodemographic', 'midwifery care', 'Mental health services', 'Medicaid', 'Cost analysis', 'Adolescent'])
      expect(article.funder).to all(be_a(String))
      expect(article.funder).to eq(['NIH National Human Genome Research Institute Phenomics First Resource', 'Center of Excellence in Genomic Science', 'Office of the Director', 'National Institutes of Health', 'Office of Science', 'Office of Basic Energy Sciences', 'US Department of Energy', 'National Human Genome Research Institute', 'BBSRC Growing Health', 'Delivering Sustainable Wheat', 'Gene Ontology Consortium', 'Alliance of Genome Resources', 'Dicty database and Stock Center', 'NICHD', 'NIH', 'EMBL-EBI Core Funds', 'Wellcome Grant', 'Open Targets', 'Biogen', 'Celgene', 'EMBL-EBI', 'GSK', 'Takeda', 'Sanofi', 'Wellcome Trust Sanger Institute'])
    end
  end
end
