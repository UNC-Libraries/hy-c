# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tasks::DimensionsQueryService do
    let(:service) { described_class.new }

    before do
        stub_request(:post, "https://app.dimensions.ai/api/auth").to_return(
            body: { data: { token: 'test_token' } }.to_json.to_s
        )
    end
    
    describe '#retrieve_token' do
        it 'returns a token' do
        token = service.retrieve_token
        Rails.logger.info("Token: #{token}")
        expect(token).to eql 'test_token'
        end
    end

    describe '#initialize' do
        it 'creates a new instance of the service' do
        expect(service).to be_an_instance_of described_class
        end
    end
end