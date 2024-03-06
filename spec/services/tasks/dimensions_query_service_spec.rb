# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::DimensionsQueryService do

    before do
        stub_request(:post, "https://app.dimensions.ai/api/auth")
            .with(
                body: { 'key' => ENV['DIMENSIONS_API_KEY'] }.to_json,
                headers: { 'Content-Type' => 'application/json' }
                )
                .to_return( status:200, body: {token: 'test_token'}.to_json, headers: { 'Content-Type' => 'application/json' })
    end
    
    describe '#retrieve_token' do
        it 'returns a token' do
            dimensions_query_service = Tasks::DimensionsQueryService.new
            token = dimensions_query_service.retrieve_token
            expect(token).to eq('test_token')
        end
    end

  describe '#initialize' do
    it 'creates a new instance of the service' do
      dimensions_query_service = Tasks::DimensionsQueryService.new
      expect(dimensions_query_service).to be_an_instance_of described_class
    end
  end

  describe '#query_dimensions' do
    it 'returns the result of a dsl query' do

    end
  end
end
