# frozen_string_literal: true
require 'rails_helper'

RSpec.describe ApplicationController, type: :controller do
  describe 'handling Faraday::TimeoutError' do
    controller(ApplicationController) do
      def index
        raise Faraday::TimeoutError, 'Connection timed out'
      end
    end

    it 'renders a 408 response' do
      get :index
      expect(response).to have_http_status(:request_timeout)
    end
  end
end
