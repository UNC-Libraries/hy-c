# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::DimensionsQueryService do
  let(:publication_test_data) do
    File.read(File.expand_path('../../../fixtures/files/dimensions_api_response.json', __FILE__))
  end

  before do
    query_string = <<~QUERY
                        search publications in raw_affiliations#{' '}
                        for """
                        "University of North Carolina, Chapel Hill" OR "UNC"
                        """#{'  '}
                        return publications
                    QUERY

    stub_request(:post, 'https://app.dimensions.ai/api/auth')
        .with(
            body: { 'key' => ENV['DIMENSIONS_API_KEY'] }.to_json,
            headers: { 'Content-Type' => 'application/json' }
            )
            .to_return(status: 200, body: {token: 'test_token'}.to_json, headers: { 'Content-Type' => 'application/json' })

    stub_request(:post, 'https://app.dimensions.ai/api/dsl')
        .with(
            body: query_string,
            headers: { 'Content-Type' => 'application/json' })
            .to_return(status: 200, body: publication_test_data.to_json, headers: { 'Content-Type' => 'application/json' })
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
    it 'returns unc affiliated articles from a dsl query' do
      dimensions_query_service = Tasks::DimensionsQueryService.new
      publications = dimensions_query_service.query_dimensions
      expect(publications).to eq(publication_test_data['publications'])
    end
  end
end
