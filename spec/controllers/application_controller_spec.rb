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

  describe '#replace_invalid_f_parameter' do
    controller(ApplicationController) do
      def index
        @params = params
      end
    end

    it 'replaces a string f parameter with an empty Parameters object' do
      get :index, params: { f: 'edit' }
      expect(subject.instance_variable_get(:@params)[:f]).to eq(ActionController::Parameters.new({}))
    end

    it 'does not replace f parameter when it is a Parameters object' do
      get :index, params: { f: { 'resource_type_sim' => ['Article'] }}
      expect(subject.instance_variable_get(:@params)[:f]).to eq(ActionController::Parameters.new({'resource_type_sim' => ['Article']}))
    end
  end

  describe '#set_locale' do
    controller(ApplicationController) do
      def index
        @params = params
      end
    end

    it 'retains valid locale' do
      get :index, params: { locale: 'fr' }
      expect(I18n.locale).to eq :fr
      expect(subject.instance_variable_get(:@params)[:locale]).to eq 'fr'
    end

    it 'overrides invalid locale' do
      get :index, params: { locale: 'http://example.com/why' }
      expect(I18n.locale).to eq :en
      expect(subject.instance_variable_get(:@params)[:locale]).to eq 'en'
    end
  end
end
