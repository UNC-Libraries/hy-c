# frozen_string_literal: true
require 'rails_helper'
RSpec.describe Hyrax::StatsController do
  let(:user) { FactoryBot.create(:user) }
  let(:usage) { double }

  before do
    allow_any_instance_of(User).to receive(:groups).and_return([])
  end
  routes { Hyrax::Engine.routes }

  describe 'work' do
    before do
      sign_in user
      request.env['HTTP_REFERER'] = 'http://test.host/foo'
    end

    it 'returns a 404' do
      get :work, params: { id: 'zp38wq32v' }
      expect(response).to_not be_successful
    end
  end

  describe 'file' do

    before do
      sign_in user
      request.env['HTTP_REFERER'] = 'http://test.host/foo'
    end

    it 'returns a 404' do
      get :file, params: { id: 'zp38wq32v' }
      expect(response).to_not be_successful
    end
  end
end
