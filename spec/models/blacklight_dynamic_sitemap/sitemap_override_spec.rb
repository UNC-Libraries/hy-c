# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BlacklightDynamicSitemap::Sitemap do
  subject(:sitemap) { described_class.new }

  let(:exponent) { 3 }
  let(:hashed_id_field) { 'hashed_id_ssi' }
  let(:unique_id_field) { 'id' }
  let(:last_modified_field) { 'timestamp' }
  let(:solr_endpoint) { 'select' }
  let(:engine_config) { double('engine_config') }
  let(:index_connection) { double('index_connection') }
  let(:solr_response) do
    {
      'response' => {
        'docs' => [
          { 'id' => 'doc1', 'timestamp' => '2023-01-01T00:00:00Z', 'has_model_ssim' => ['Article'] },
          { 'id' => 'doc2', 'timestamp' => '2023-01-02T00:00:00Z', 'has_model_ssim' => ['Dataset'] }
        ]
      }
    }
  end
  let(:valid_id) { 'abc' } # Match exponent length

  before do
    allow(sitemap).to receive(:exponent).and_return(exponent)
    allow(sitemap).to receive(:hashed_id_field).and_return(hashed_id_field)
    allow(sitemap).to receive(:unique_id_field).and_return(unique_id_field)
    allow(sitemap).to receive(:last_modified_field).and_return(last_modified_field)
    allow(sitemap).to receive(:solr_endpoint).and_return(solr_endpoint)
    allow(sitemap).to receive(:engine_config).and_return(engine_config)
    allow(sitemap).to receive(:index_connection).and_return(index_connection)
    allow(sitemap).to receive(:show_params) do |id, params|
      params # Return the second parameter as-is
    end
    allow(engine_config).to receive(:default_params).and_return({ q: '*:*' })
  end

  describe '#get' do
    context 'when id has incorrect length' do
      it 'returns an empty array' do
        expect(sitemap.get('a')).to eq([])
        expect(sitemap.get('abcd')).to eq([])
      end
    end

    context 'when id has correct length' do
      it 'queries Solr with the correct parameters' do
        expected_params = {
          fq: ["{!prefix f=#{hashed_id_field} v=#{valid_id}}", 'visibility_ssi:open'],
          fl: "#{unique_id_field},#{last_modified_field},has_model_ssim",
          rows: 20_000_000,
          facet: false,
          q: '*:*'
        }

        allow(index_connection).to receive(:public_send)
          .and_return(solr_response)

        result = sitemap.get(valid_id)
        expect(result).to eq(solr_response.dig('response', 'docs'))
        expect(index_connection).to have_received(:public_send)
          .with(solr_endpoint, hash_including(params: expected_params))
      end
    end
  end
end
