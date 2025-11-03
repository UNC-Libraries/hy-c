# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::NsfIngest::Backlog::Utilities::MetadataRetrievalHelper do
  let(:helper) { described_class }
  let(:doi) { '10.1234/example' }

  before do
    allow(Rails.logger).to receive(:error)
  end

  describe '.fetch_metadata_for_doi' do
    let(:url) { 'https://api.crossref.org/works/' + CGI.escape(doi) }

    before do
      allow(URI).to receive(:join).and_return(url)
    end

    it 'logs error and returns nil when DOI is blank' do
      result = helper.fetch_metadata_for_doi(source: 'crossref', doi: '')
      expect(result).to be_nil
      expect(Rails.logger).to have_received(:error)
          .with(a_string_including('Error retrieving Crossref metadata for DOI'))
    end

    it 'logs error and returns nil for unsupported source' do
      result = helper.fetch_metadata_for_doi(source: 'invalid', doi: doi)
      expect(result).to be_nil
      expect(Rails.logger).to have_received(:error)
          .with(a_string_including('Error retrieving Invalid metadata for DOI'))
    end

    it 'returns parsed metadata when HTTP 200 and source crossref' do
      res = double('Response', code: 200, body: '{"message": {"title": "X"}}')
      allow(HTTParty).to receive(:get).and_return(res)
      result = helper.fetch_metadata_for_doi(source: 'crossref', doi: doi)
      expect(result).to eq({ 'title' => 'X' })
    end

    it 'returns parsed metadata when HTTP 200 and source openalex' do
      res = double('Response', code: 200, body: '{"title": "OpenAlex"}')
      allow(HTTParty).to receive(:get).and_return(res)
      result = helper.fetch_metadata_for_doi(source: 'openalex', doi: doi)
      expect(result).to eq({ 'title' => 'OpenAlex' })
    end

    it 'returns parsed metadata when HTTP 200 and source datacite' do
      res = double('Response', code: 200, body: '{"data": {"attributes": "ok"}}')
      allow(HTTParty).to receive(:get).and_return(res)
      result = helper.fetch_metadata_for_doi(source: 'datacite', doi: doi)
      expect(result).to eq({ 'attributes' => 'ok' })
    end

    it 'logs error and returns nil on non-200 HTTP response' do
      res = double('Response', code: 404, body: '{}')
      allow(HTTParty).to receive(:get).and_return(res)
      result = helper.fetch_metadata_for_doi(source: 'crossref', doi: doi)
      expect(result).to be_nil
      expect(Rails.logger).to have_received(:error)
        .with(a_string_including('Failed to retrieve metadata'))
    end

    it 'logs error and returns nil when HTTParty raises exception' do
      allow(HTTParty).to receive(:get).and_raise(StandardError, 'network down')
      result = helper.fetch_metadata_for_doi(source: 'crossref', doi: doi)
      expect(result).to be_nil
      expect(Rails.logger).to have_received(:error)
        .with(a_string_including('Error retrieving Crossref metadata'))
    end
  end

  describe '.parse_response' do
    it 'extracts Crossref message field' do
      res = double('Response', body: '{"message": {"title": "A"}}')
      expect(helper.parse_response(res, 'crossref', doi)).to eq({ 'title' => 'A' })
    end

    it 'returns full JSON for OpenAlex' do
      res = double('Response', body: '{"title": "B"}')
      expect(helper.parse_response(res, 'openalex', doi)).to eq({ 'title' => 'B' })
    end

    it 'extracts data field for Datacite' do
      res = double('Response', body: '{"data": {"key": "val"}}')
      expect(helper.parse_response(res, 'datacite', doi)).to eq({ 'key' => 'val' })
    end
  end

  describe '.generate_openalex_abstract' do
    it 'returns nil if no abstract_inverted_index' do
      expect(helper.generate_openalex_abstract(nil)).to be_nil
      expect(helper.generate_openalex_abstract({})).to be_nil
    end

    it 'constructs ordered abstract text from inverted index' do
      metadata = {
        'abstract_inverted_index' => {
          'science' => [1],
          'Open' => [0],
          'rocks' => [2]
        }
      }
      result = helper.generate_openalex_abstract(metadata)
      expect(result).to eq('Open science rocks')
    end
  end

  describe '.extract_keywords_from_openalex' do
    it 'extracts and merges concepts and keywords uniquely' do
      metadata = {
        'concepts' => [{ 'display_name' => 'Hyrax' }],
        'keywords' => [{ 'display_name' => 'UNC' }, { 'display_name' => 'Hyrax' }]
      }
      result = helper.extract_keywords_from_openalex(metadata)
      expect(result).to contain_exactly('Hyrax', 'UNC')
    end

    it 'returns empty array when metadata is empty' do
      expect(helper.extract_keywords_from_openalex({})).to eq([])
    end
  end
end
