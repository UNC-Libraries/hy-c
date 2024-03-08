# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::DimensionsQueryService do
  let(:dimensions_query_response) do
    File.read(File.expand_path('../../../fixtures/files/dimensions_query_response.json', __FILE__))
  end

  let(:dimensions_query_response_non_doi) do
    File.read(File.expand_path('../../../fixtures/files/dimensions_query_response_non_doi.json', __FILE__))
  end

  before do
    stub_request(:post, 'https://app.dimensions.ai/api/auth')
        .with(
            body: { 'key' => ENV['DIMENSIONS_API_KEY'] }.to_json,
            headers: { 'Content-Type' => 'application/json' }
            )
            .to_return(status: 200, body: {token: 'test_token'}.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  describe '#initialize' do
    it 'creates a new instance of the service' do
      dimensions_query_service = Tasks::DimensionsQueryService.new
      expect(dimensions_query_service).to be_an_instance_of described_class
    end
  end

  describe '#retrieve_token' do
    it 'returns a token' do
      dimensions_query_service = Tasks::DimensionsQueryService.new
      token = dimensions_query_service.retrieve_token
      expect(token).to eq('test_token')
    end
  end

  describe '#query_dimensions' do
    it 'returns unc affiliated articles that have dois' do
        query_string = <<~QUERY
                        search publications where doi is not empty in raw_affiliations#{' '}
                        for """
                        "University of North Carolina, Chapel Hill" OR "UNC"
                        """#{'  '}
                        return publications[basics + extras]
                    QUERY

        stub_request(:post, 'https://app.dimensions.ai/api/dsl')
        .with(
            body: query_string,
            headers: { 'Content-Type' => 'application/json' })
            .to_return(status: 200, body: dimensions_query_response.to_json, headers: { 'Content-Type' => 'application/json' })
    
      dimensions_query_service = Tasks::DimensionsQueryService.new
      publications = dimensions_query_service.query_dimensions
      expect(publications).to eq(dimensions_query_response['publications'])
    end

    it 'returns unc affiliated articles that do not have dois if specified' do
        query_string = <<~QUERY
                        search publications where doi is empty in raw_affiliations#{' '}
                        for """
                        "University of North Carolina, Chapel Hill" OR "UNC"
                        """#{'  '}
                        return publications[basics + extras]
                    QUERY

        stub_request(:post, 'https://app.dimensions.ai/api/dsl')
        .with(
            body: query_string,
            headers: { 'Content-Type' => 'application/json' })
            .to_return(status: 200, body: dimensions_query_response_non_doi.to_json, headers: { 'Content-Type' => 'application/json' })
    
      dimensions_query_service = Tasks::DimensionsQueryService.new
      publications = dimensions_query_service.query_dimensions(with_doi: false)
      expect(publications).to eq(dimensions_query_response_non_doi['publications'])
    end
  end
end
