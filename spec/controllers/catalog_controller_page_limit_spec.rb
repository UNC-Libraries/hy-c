# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CatalogController, type: :controller do
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
  end
end
