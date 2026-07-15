# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CatalogController, type: :controller do
  describe 'facet page limits' do
    before do
      request.headers['sec-fetch-dest'] = 'empty'
      allow(CatalogController).to receive(:turnstile_enabled?).and_return(false)
    end

    it 'returns not found for facet pages beyond the configured limit' do
      get :facet, params: { id: CatalogController.blacklight_config.facet_fields.keys.first, 'facet.page': '21' }

      expect(response).to have_http_status(:not_found)
    end
  end
end
