# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CatalogController, type: :controller do
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
end
