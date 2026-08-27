# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CatalogController, type: :controller do
  describe 'Blacklight search result limits' do
    subject(:blacklight_config) { described_class.blacklight_config }

    it 'limits available search result sizes in the UI' do
      expect(blacklight_config.per_page).to eq([10, 20])
      expect(blacklight_config.default_per_page).to eq(10)
    end
  end

  describe 'search result size parameter limits' do
    it 'clamps per_page and rows to the configured maximum' do
      params = ActionController::Parameters.new(per_page: '50', rows: '100')
      allow(controller).to receive(:params).and_return(params)

      controller.send(:clamp_search_result_size_params)

      expect(params[:per_page]).to eq('20')
      expect(params[:rows]).to eq('20')
    end

    it 'returns bad request for malformed result size values' do
      params = ActionController::Parameters.new(per_page: '20x')
      allow(controller).to receive(:params).and_return(params)
      allow(controller).to receive(:head)

      controller.send(:clamp_search_result_size_params)

      expect(controller).to have_received(:head).with(:bad_request)
    end
  end

  describe 'dest query parameter handling' do
    before do
      request.headers['sec-fetch-dest'] = 'empty'
      allow(CatalogController).to receive(:turnstile_enabled?).and_return(false)
    end

    it 'returns not found when the query string includes dest' do
      get :index, params: { dest: '/catalog?page=2' }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'search facet count limits' do
    before do
      request.headers['sec-fetch-dest'] = 'empty'
      allow(CatalogController).to receive(:turnstile_enabled?).and_return(false)
    end

    it 'returns not found when more than five facet fields are selected' do
      get :index, params: { f: facet_params_for(6) }

      expect(response).to have_http_status(:not_found)
    end

    it 'allows searches with up to five facet fields selected' do
      get :index, params: { f: facet_params_for(5) }

      expect(response).not_to have_http_status(:not_found)
    end

    it 'allows normal browse requests with a single facet field' do
      get :index, params: { f: { human_readable_type_sim: ['Collection'] } }

      expect(response).not_to have_http_status(:not_found)
    end

    def facet_params_for(count)
      CatalogController.blacklight_config.facet_fields.keys.first(count).each_with_object({}) do |field, params|
        params[field] = ['test']
      end
    end
  end

  describe 'facet page limits' do
    before do
      request.headers['sec-fetch-dest'] = 'empty'
      allow(CatalogController).to receive(:turnstile_enabled?).and_return(false)
    end

    it 'returns not found for facet pages beyond the configured limit' do
      get :facet, params: { id: CatalogController.blacklight_config.facet_fields.keys.first, 'facet.page': '21' }

      expect(response).to have_http_status(:not_found)
    end

    it 'returns bad request for malformed facet page values' do
      get :facet, params: { id: CatalogController.blacklight_config.facet_fields.keys.first, 'facet.page': '21x' }

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe 'search page limits' do
    before do
      request.headers['sec-fetch-dest'] = 'empty'
      allow(CatalogController).to receive(:turnstile_enabled?).and_return(false)
    end

    it 'returns not found for pages beyond the configured limit' do
      get :index, params: { page: '21' }

      expect(response).to have_http_status(:not_found)
    end

    it 'allows requests within the configured limit' do
      get :index, params: { page: '20' }

      expect(response).not_to have_http_status(:not_found)
    end

    it 'returns bad request for malformed page values' do
      get :index, params: { page: '200x' }

      expect(response).to have_http_status(:bad_request)
    end

    it 'allows quoted all_fields searches' do
      get :index, params: { q: '"Doctor of Nursing Practice"', search_field: 'all_fields' }

      expect(response).to have_http_status(:success)
    end
  end
end
