# frozen_string_literal: true
require 'rails_helper'
require Rails.root.join('app/overrides/controllers/hyrax/admin/analytics/work_reports_controller_override.rb')

RSpec.describe Hyrax::Admin::Analytics::WorkReportsController, type: :controller do
  routes { Hyrax::Engine.routes }
  describe 'GET #index' do
    context 'when user is not logged in' do
      it 'raises NoMethodError for nil:NilClass' do
        expect {
          get :index
        }.to raise_error(NoMethodError, /undefined method `ability' for nil:NilClass/)
      end
    end
  end
end
