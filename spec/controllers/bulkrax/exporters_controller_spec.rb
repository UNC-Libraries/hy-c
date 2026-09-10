# frozen_string_literal: true
require 'rails_helper'
require Rails.root.join('app/overrides/controllers/concerns/bulkrax/datatables_behavior_override.rb')
require Rails.root.join('app/overrides/controllers/bulkrax/exporters_controller_override.rb')

RSpec.describe Bulkrax::ExportersController, type: :controller do
  routes { Bulkrax::Engine.routes }

  let(:admin_user) { FactoryBot.create(:admin) }

  before do
    sign_in admin_user
    Bulkrax::Exporter.delete_all
    allow(controller).to receive(:authorize!).and_return(true)
    allow(controller).to receive(:table_page).and_return(1)
    allow(controller).to receive(:table_per_page).and_return(1)
    allow(controller).to receive(:table_order).and_return('name ASC')
  end

  describe 'GET #exporter_table' do
    before do
      FactoryBot.create(:bulkrax_exporter_worktype, name: 'Hyc Export')
      FactoryBot.create(:bulkrax_exporter_worktype, name: 'Hyc Two Export')
      FactoryBot.create(:bulkrax_exporter_worktype, name: 'Boxy Export')
    end

    context 'when there is a search filter' do
      before do
        allow(controller).to receive(:exporter_table_search).and_return(['name ILIKE ?', '%Hyc%'])
      end

      it 'returns the filtered count before pagination is applied' do
        get :exporter_table, format: :json

        expect(response).to be_successful

        body = JSON.parse(response.body)

        expect(body['recordsTotal']).to eq(3)
        expect(body['recordsFiltered']).to eq(2)
        expect(body['data'].size).to eq(1)
        expect(body['data'].first['name']).to include('Hyc Export')
      end
    end

    context 'when there is no search filter' do
      before do
        allow(controller).to receive(:exporter_table_search).and_return(nil)
      end

      it 'returns the total exporter count as the filtered count' do
        get :exporter_table, format: :json

        expect(response).to be_successful

        body = JSON.parse(response.body)

        expect(body['recordsTotal']).to eq(3)
        expect(body['recordsFiltered']).to eq(3)
        expect(body['data'].size).to eq(1)
      end
    end
  end
end
