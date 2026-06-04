# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::PubmedIngest::SharedUtilities::AttributeBuilders::PmcAttributeBuilder, type: :model do
  let(:admin_set) { FactoryBot.create(:admin_set) }
  let(:depositor) { FactoryBot.create(:admin, uid: 'admin') }
  let(:skipped_rows) do
    [
      { 'pmid' => '12345678', 'pmcid' => 'PMC11111111' },
      { 'pmid' => '99999999', 'pmcid' => 'PMC87654321' }
    ]
  end
  let(:metadata) { Nokogiri::XML(File.read(Rails.root.join('spec/fixtures/files/pmc_api_response_multi.xml'))) }
  let(:article_node) { metadata.xpath('//article').first }
  let(:article) { Article.new }
  let(:builder) { described_class.new(article_node, admin_set, depositor.uid) }
  let(:json_metadata) do
    {
      'pmcid' => 'PMC11435997',
      'version' => 1,
      'pmid' => 39_338_762,
      'doi' => '10.3390/s24186017',
      'mid' => nil,
      'title' => 'Harnessing the Heart\'s Magnetic Field for Advanced Diagnostic Techniques',
      'citation' => 'Sensors (Basel). 2024 Sep 18;24(18):6017. doi: 10.3390/s24186017',
      'is_pmc_openaccess' => true,
      'is_manuscript' => true,
      'is_historical_ocr' => false,
      'is_retracted' => false,
      'license_code' => 'CC BY',
      'text_url' => 's3://pmc-oa-opendata/PMC11435997.1/PMC11435997.1.txt?md5=72e1bcfda57e8f60d7d826308220a289',
      'pdf_url' => 's3://pmc-oa-opendata/PMC11435997.1/PMC11435997.1.pdf?md5=eda1c9a66dfa5a7bad9d8836541eacf0',
      'xml_url' => 's3://pmc-oa-opendata/PMC11435997.1/PMC11435997.1.xml?md5=e7ace4d299c3c5e5bf582253045584a0',
      'media_urls' => [
        's3://pmc-oa-opendata/PMC11435997.1/sensors-24-06017-g001.jpg?md5=5ef5ebe10b8e9202f5aa740d5c52e1c4',
        's3://pmc-oa-opendata/PMC11435997.1/sensors-24-06017-g002.jpg?md5=0485b7c41387644948b0ccc08ad38938'
      ]
    }
  end

  describe '#find_skipped_row' do
    it 'matches by pmid' do
      allow(article_node).to receive(:at_xpath)
                               .with('.//article-id[@pub-id-type="pmid"]')
                               .and_return(double(text: '12345678'))
      allow(article_node).to receive(:at_xpath)
                               .with('.//article-id[@pub-id-type="pmcid"]')
                               .and_return(nil)

      result = builder.find_skipped_row(skipped_rows, article)
      expect(result['pmid']).to eq('12345678')
    end

    it 'matches by pmcid' do
      allow(article_node).to receive(:at_xpath)
                               .with('.//article-id[@pub-id-type="pmid"]')
                               .and_return(nil)
      allow(article_node).to receive(:at_xpath)
                               .with('.//article-id[@pub-id-type="pmcid"]')
                               .and_return(double(text: 'PMC87654321'))

      result = builder.find_skipped_row(skipped_rows, article)
      expect(result['pmcid']).to eq('PMC87654321')
    end
  end

  describe '#generate_authors' do
    it 'returns authors with name, orcid, and affiliation' do
      authors = builder.send(:generate_authors)
      expect(authors).to all(include('name', 'orcid', 'index', 'other_affiliation'))
      expect(authors.first['name']).to match(/.+, .+/)
    end
  end

  describe '#set_identifiers' do
    it 'sets article.identifier, doi, and issn' do
      builder.send(:set_identifiers, article)
      expect(article.identifier).to include(a_string_matching(/^PMID:/))
      expect(article.identifier).to include(a_string_matching(/^PMCID:/))
      expect(article.identifier).to include(a_string_matching(/^DOI:/))

      # Expect all DOIs to follow the standard "10.xxxx/..." format, without a URL prefix.
      # - \A and \z ensure the whole string is matched
      # - 10. is the fixed DOI prefix
      # - \d{4,9} is the registrant code (4–9 digits)
      # - /.+ is the suffix assigned by the publisher
      expect(article.doi).to match(%r{\A10\.\d{4,9}/.+\z}).or be_empty
      expect(article.issn).to all(be_a(String))
    end
  end

  describe '#set_journal_attributes' do
    it 'sets journal title, volume, issue, and pages' do
      # Mocking missing values for pagination
      allow(article_node).to receive(:at_xpath).and_call_original
      allow(article_node).to receive(:at_xpath).with('front/article-meta/fpage').and_return(double('Nokogiri::XML::Node', text: '1'))
      allow(article_node).to receive(:at_xpath).with('front/article-meta/lpage').and_return(double('Nokogiri::XML::Node', text: '10'))

      builder.send(:set_journal_attributes, article)
      expect(article.journal_title).to be_present
      expect(article.journal_volume).to be_present
      expect(article.journal_issue).to be_present
      expect(article.page_start).to be_present
      expect(article.page_end).to be_present
    end
  end

  describe '#apply_json_metadata' do
    before do
      allow(article_node).to receive(:at_xpath).and_call_original
      allow(article_node).to receive(:at_xpath)
                               .with('.//article-id[@pub-id-type="pmcid"]')
                               .and_return(double(text: 'PMC11435997'))
    end

    it 'sets license and edition from fetched json_metadata' do
      allow(builder).to receive(:fetch_json_metadata).with('PMC11435997').and_return(json_metadata)

      builder.send(:apply_json_metadata, article)

      expect(article.license).to eq(['http://creativecommons.org/licenses/by/4.0/'])
      expect(article.edition).to eq('Postprint')
    end

    it 'skips license and edition for TDM and non-manuscript metadata' do
      allow(builder).to receive(:fetch_json_metadata).with('PMC11435997')
                                                     .and_return(json_metadata.merge('license_code' => 'TDM', 'is_manuscript' => false))

      builder.send(:apply_json_metadata, article)

      expect(article.license).to be_empty
      expect(article.edition).to be_nil
    end

    it 'warns and skips license when license_code is not mapped' do
      allow(builder).to receive(:fetch_json_metadata).with('PMC11435997')
                                                     .and_return(json_metadata.merge('license_code' => 'CC BY-XYZ'))
      allow(Rails.logger).to receive(:warn)

      builder.send(:apply_json_metadata, article)

      expect(article.license).to be_empty
      expect(Rails.logger).to have_received(:warn)
        .with("[PMC] Unmapped license code 'CC BY-XYZ' for PMCID PMC11435997")
    end
  end

  describe '#apply_additional_basic_attributes' do
    before do
      allow(builder).to receive(:fetch_json_metadata).and_return(nil)
    end

    it 'sets title, abstract, date_issued, publisher, keyword, and funder' do
      builder.send(:apply_additional_basic_attributes, article)
      expect(article.title).to be_present
      expect(article.abstract).to be_present
      expect(article.date_issued).to match(/\d{4}-\d{2}-\d{2}/)
      expect(article.publisher).to all(be_a(String)).or be_empty
      expect(article.keyword).to all(be_a(String))
      expect(article.funder).to all(be_a(String))
    end

    it 'handles missing abstract gracefully' do
      allow(article_node).to receive(:xpath).and_call_original
      allow(article_node).to receive(:xpath)
                               .with('front/article-meta/abstract')
                               .and_return(double('Nokogiri::XML::Node', text: ''))
      builder.send(:apply_additional_basic_attributes, article)
      expect(article.abstract).to eq(['N/A'])
    end

    it 'applies json metadata enrichment through the basic attributes flow' do
      allow(article_node).to receive(:at_xpath).and_call_original
      allow(article_node).to receive(:at_xpath)
                               .with('.//article-id[@pub-id-type="pmcid"]')
                               .and_return(double(text: 'PMC11435997'))
      allow(builder).to receive(:fetch_json_metadata).with('PMC11435997').and_return(json_metadata)

      builder.send(:apply_additional_basic_attributes, article)

      expect(article.license).to eq(['http://creativecommons.org/licenses/by/4.0/'])
      expect(article.edition).to eq('Postprint')
    end
  end

  describe '#license_uri_for_code' do
    {
      'CC BY' => 'http://creativecommons.org/licenses/by/4.0/',
      'CC BY-SA' => 'http://creativecommons.org/licenses/by-sa/4.0/',
      'CC BY-ND' => 'http://creativecommons.org/licenses/by-nd/4.0/',
      'CC BY-NC' => 'http://creativecommons.org/licenses/by-nc/4.0/',
      'CC BY-NC-SA' => 'http://creativecommons.org/licenses/by-nc-sa/4.0/',
      'CC BY-NC-ND' => 'http://creativecommons.org/licenses/by-nc-nd/4.0/'
    }.each do |code, expected_uri|
      it "maps #{code} to #{expected_uri}" do
        expect(builder.send(:license_uri_for_code, code)).to eq(expected_uri)
      end
    end
  end
end
