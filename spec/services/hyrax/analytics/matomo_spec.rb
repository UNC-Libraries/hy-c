# frozen_string_literal: true
require 'rails_helper'
require Rails.root.join('app/overrides/services/hyrax/analytics/matomo_override.rb')

RSpec.describe Hyrax::Analytics::Matomo do

  let(:dummy_class) do
    Class.new do
      include Hyrax::Analytics::Matomo
    end
  end

  describe '.get' do
    context 'when the response is successful' do
      it 'returns parsed JSON response' do
        allow(Faraday).to receive(:get).and_return(double('response', success?: true, body: '{"key": "value"}'))
        expect(dummy_class.get({})).to eq({ 'key' => 'value' })
      end
    end

    context 'when the response is not successful' do
      it 'raises a MatomoError' do
        allow(Faraday).to receive(:get).and_return(double('response', success?: false, status: 404, reason_phrase: 'Not Found'))
        expect {
          dummy_class.get({})
        }.to raise_error(MatomoError, 'Failed to fetch data from Matomo API: 404 - Not Found')
      end
    end
  end
end
