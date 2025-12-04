# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::RosapIngest::Backlog::Utilities::HTMLParsingService do
  let(:html_with_full_metadata) do
    <<~HTML
      <!DOCTYPE html>
      <html>
        <head>
          <meta name="citation_title" content="Test Document Title" />
          <meta name="citation_abstract" content="This is a test abstract." />
          <meta name="citation_publication_date" content="2023-05-01" />
          <meta name="citation_author" content="Smith, John" />
          <meta name="citation_author" content="Doe, Jane" />
          <meta name="citation_keywords" content="Testing" />
          <meta name="citation_keywords" content="Research" />
        </head>
        <body>
          <h1 id="mainTitle">Test Document Title</h1>
          <div id="collapseDetails">This is a test abstract.</div>
          <div class="bookHeaderListData"><p>2023-05-01</p></div>
      #{'    '}
          <div class="bookDetails-row">
            <div class="bookDetailsLabel"><b>Corporate Publisher:</b></div>
            <div class="bookDetailsData"><a>Test Publisher</a></div>
          </div>
      #{'    '}
          <div id="mesh-keywords">
            <a id="metadataLink-Subject/TRT Terms-Testing">Testing</a>
            <a id="metadataLink-Subject/TRT Terms-Research">Research</a>
          </div>
      #{'    '}
          <div id="moretextPAmods.sm_creator">
            <a id="metadataLink-Creators-Smith, John">Smith, John</a>
            <a href="https://orcid.org/0000-0001-2345-6789"><img src="orcid.png" /></a>
            <a id="metadataLink-Creators-Doe, Jane">Doe, Jane</a>
            <a href="https://orcid.org/0000-0002-3456-7890"><img src="orcid.png" /></a>
          </div>
        </body>
      </html>
    HTML
  end

  let(:html_with_minimal_metadata) do
    <<~HTML
      <!DOCTYPE html>
      <html>
        <head>
          <meta name="citation_title" content="Minimal Document" />
        </head>
        <body>
          <h1 id="mainTitle">Minimal Document</h1>
        </body>
      </html>
    HTML
  end

  before do
    allow(LogUtilsHelper).to receive(:double_log)
  end

  describe '#parse_metadata_from_html' do
    context 'when HTML contains full metadata' do
      let(:result) { described_class.parse_metadata_from_html(html_with_full_metadata) }

      it 'extracts the title from h1 element' do
        expect(result['title']).to eq('Test Document Title')
      end

      it 'extracts the abstract from details section' do
        expect(result['abstract']).to eq('This is a test abstract.')
      end

      it 'extracts the publication date' do
        expect(result['date_issued']).to eq('2023-05-01')
      end

      it 'extracts the publisher' do
        expect(result['publisher']).to eq('Test Publisher')
      end

      it 'extracts keywords' do
        expect(result['keywords']).to contain_exactly('Testing', 'Research')
      end

      it 'extracts authors with ORCIDs' do
        expect(result['authors']).to match_array([
          { 'name' => 'Smith, John', 'orcid' => '0000-0001-2345-6789', 'index' => '0' },
          { 'name' => 'Doe, Jane', 'orcid' => '0000-0002-3456-7890', 'index' => '1' }
        ])
      end

      it 'sets funder as empty array' do
        expect(result['funder']).to eq([])
      end
    end

    context 'when HTML contains minimal metadata' do
      let(:result) { described_class.parse_metadata_from_html(html_with_minimal_metadata) }

      it 'extracts available title' do
        expect(result['title']).to eq('Minimal Document')
      end

      it 'returns nil for missing abstract' do
        expect(result['abstract']).to be_nil
      end

      it 'returns nil for missing date' do
        expect(result['date_issued']).to be_nil
      end

      it 'returns nil for missing publisher' do
        expect(result['publisher']).to be_nil
      end

      it 'returns empty array for missing keywords' do
        expect(result['keywords']).to eq([])
      end

      it 'returns empty array for missing authors' do
        expect(result['authors']).to eq([])
      end
    end

    context 'when title is only in meta tag' do
      let(:html_meta_only) do
        <<~HTML
          <!DOCTYPE html>
          <html>
            <head>
              <meta name="citation_title" content="Meta Title Only" />
            </head>
            <body></body>
          </html>
        HTML
      end

      it 'falls back to meta tag for title' do
        result = described_class.parse_metadata_from_html(html_meta_only)
        expect(result['title']).to eq('Meta Title Only')
      end
    end
  end

  describe '#extract_keywords' do
    context 'when keywords are in meta tags' do
      let(:doc) { Nokogiri::HTML(html_with_full_metadata) }

      it 'extracts keywords from meta tags' do
        keywords = described_class.extract_keywords(doc)
        expect(keywords).to contain_exactly('Testing', 'Research')
      end
    end

    context 'when keywords are only in details section' do
      let(:html_details_only) do
        <<~HTML
          <!DOCTYPE html>
          <html>
            <body>
              <div id="mesh-keywords">
                <a id="metadataLink-Subject/TRT Terms-Keyword1">Keyword1</a>
                <a id="metadataLink-Subject/TRT Terms-Keyword2">Keyword2</a>
              </div>
            </body>
          </html>
        HTML
      end

      it 'falls back to details section' do
        doc = Nokogiri::HTML(html_details_only)
        keywords = described_class.extract_keywords(doc)
        expect(keywords).to contain_exactly('Keyword1', 'Keyword2')
      end
    end

    context 'when no keywords exist' do
      let(:html_no_keywords) do
        <<~HTML
          <!DOCTYPE html>
          <html><body></body></html>
        HTML
      end

      it 'returns empty array' do
        doc = Nokogiri::HTML(html_no_keywords)
        keywords = described_class.extract_keywords(doc)
        expect(keywords).to eq([])
      end
    end
  end

  describe '#extract_authors' do
    context 'when authors are in details section with ORCIDs' do
      let(:doc) { Nokogiri::HTML(html_with_full_metadata) }

      it 'extracts authors from details section first' do
        authors = described_class.extract_authors(doc)
        expect(authors).to match_array([
          { 'name' => 'Smith, John', 'orcid' => '0000-0001-2345-6789', 'index' => '0' },
          { 'name' => 'Doe, Jane', 'orcid' => '0000-0002-3456-7890', 'index' => '1' }
        ])
      end
    end

    context 'when authors are only in meta tags' do
      let(:html_meta_authors) do
        <<~HTML
          <!DOCTYPE html>
          <html>
            <head>
              <meta name="citation_author" content="Jones, Bob" />
              <meta name="citation_author" content="Lee, Sarah" />
            </head>
            <body></body>
          </html>
        HTML
      end

      it 'falls back to meta tags' do
        doc = Nokogiri::HTML(html_meta_authors)
        authors = described_class.extract_authors(doc)
        expect(authors).to match_array([
          { 'name' => 'Jones, Bob', 'orcid' => '', 'index' => '0' },
          { 'name' => 'Lee, Sarah', 'orcid' => '', 'index' => '1' }
        ])
      end
    end

    context 'when authors have no ORCID' do
      let(:html_no_orcid) do
        <<~HTML
          <!DOCTYPE html>
          <html>
            <body>
              <div id="moretextPAmods.sm_creator">
                <a id="metadataLink-Creators-Author Name">Author Name</a>
              </div>
            </body>
          </html>
        HTML
      end

      it 'returns empty string for orcid' do
        doc = Nokogiri::HTML(html_no_orcid)
        authors = described_class.extract_authors(doc)
        expect(authors.first['orcid']).to eq('')
      end
    end

    context 'when no authors exist' do
      let(:html_no_authors) do
        <<~HTML
          <!DOCTYPE html>
          <html><body></body></html>
        HTML
      end

      it 'returns empty array' do
        doc = Nokogiri::HTML(html_no_authors)
        authors = described_class.extract_authors(doc)
        expect(authors).to eq([])
      end
    end
  end

  describe '#extract_multi_value_field' do
    let(:html_with_labeled_fields) do
      <<~HTML
        <!DOCTYPE html>
        <html>
          <body>
            <div class="bookDetails-row">
              <div class="bookDetailsLabel"><b>Single Field:</b></div>
              <div class="bookDetailsData"><a>Single Value</a></div>
            </div>
            <div class="bookDetails-row">
              <div class="bookDetailsLabel"><b>Multiple Field:</b></div>
              <div class="bookDetailsData">
                <a>Value 1</a>
                <a>Value 2</a>
                <a>Value 3</a>
              </div>
            </div>
          </body>
        </html>
      HTML
    end

    let(:doc) { Nokogiri::HTML(html_with_labeled_fields) }

    context 'when extracting single value' do
      it 'returns the first value as string' do
        result = described_class.send(:extract_multi_value_field, doc, 'Single Field', multiple: false)
        expect(result).to eq('Single Value')
      end
    end

    context 'when extracting multiple values' do
      it 'returns all values as array' do
        result = described_class.send(:extract_multi_value_field, doc, 'Multiple Field', multiple: true)
        expect(result).to contain_exactly('Value 1', 'Value 2', 'Value 3')
      end
    end

    context 'when field does not exist' do
      it 'returns nil for single value' do
        result = described_class.send(:extract_multi_value_field, doc, 'Nonexistent Field', multiple: false)
        expect(result).to be_nil
      end

      it 'returns empty array for multiple values' do
        result = described_class.send(:extract_multi_value_field, doc, 'Nonexistent Field', multiple: true)
        expect(result).to eq([])
      end
    end
  end
end
