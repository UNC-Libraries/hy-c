# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('app/overrides/services/hyrax/analytics/matomo_override.rb')

RSpec.describe Hyrax::Analytics::Matomo do
  let(:dummy_class) do
    Class.new do
      include Hyrax::Analytics::Matomo
    end
  end

  describe '.daily_events_for_id' do
    let(:id) { '123' }

    context 'when action is PageView' do
      it 'returns daily events for the given id' do
        matomo_work_views = JSON.parse(File.read(File.join(Rails.root, 'spec/fixtures/files/matomo_work_views.json')))
        spec_action = 'PageView'
        spec_params = { flat: 1, label: nil }
        expected_response = [
          [Date.new(2024, 3, 6), 0],
          [Date.new(2024, 3, 20), 4],
          [Date.new(2024, 3, 21), 1],
          [Date.new(2024, 3, 22), 2],
          [Date.new(2024, 3, 25), 2],
          [Date.new(2024, 3, 26), 1],
          [Date.new(2024, 3, 28), 1],
          [Date.new(2024, 4, 3), 1],
          [Date.new(2024, 4, 4), 0]
        ]
        allow(dummy_class).to receive(:api_params).with('Actions.getPageUrls', 'day', 'last365', spec_params).and_return(matomo_work_views)
        expect(dummy_class.daily_events_for_id(id, spec_action, 'last365').list).to match_array(expected_response)
        expect(dummy_class.class_variable_get(:@@filter_pattern)).to eq("&filter_pattern=^(?=\.\*\\bconcern\\b)(?=\.\*\\b#{id}\\b)")
      end
    end

    context 'when action is DownloadIR' do
      it 'returns daily events for the given id' do
        matomo_work_downloads = JSON.parse(File.read(File.join(Rails.root, 'spec/fixtures/files/matomo_work_downloads.json')))
        spec_action = 'DownloadIR'
        spec_params = { flat: 1, label: "#{id} - DownloadIR" }
        expected_response = [
          [Date.new(2024, 3, 6), 0],
          [Date.new(2024, 3, 22), 1],
          [Date.new(2024, 3, 26), 4]
        ]
        allow(dummy_class).to receive(:api_params).with('Events.getName', 'day', 'last365', spec_params).and_return(matomo_work_downloads)
        expect(dummy_class.daily_events_for_id(id, spec_action, 'last365').list).to match_array(expected_response)
      end
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
