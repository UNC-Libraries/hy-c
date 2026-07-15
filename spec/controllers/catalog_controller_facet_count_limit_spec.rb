# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CatalogController, type: :controller do
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

    def facet_params_for(count)
      CatalogController.blacklight_config.facet_fields.keys.first(count).each_with_object({}) do |field, params|
        params[field] = ['test']
      end
    end
  end
end
