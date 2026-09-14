# frozen_string_literal: true
require 'rails_helper'
require Rails.root.join('app/overrides/controllers/concerns/bulkrax/datatables_behavior_override.rb')
require Rails.root.join('app/overrides/controllers/bulkrax/importers_controller_override.rb')

RSpec.describe Bulkrax::ImportersController, type: :controller do
  routes { Bulkrax::Engine.routes }

  let(:admin_user) { FactoryBot.create(:admin) }

  before do
    sign_in admin_user
    Bulkrax::Importer.delete_all
    allow(controller).to receive(:authorize!).and_return(true)
    allow(controller).to receive(:table_page).and_return(1)
    allow(controller).to receive(:table_per_page).and_return(1)
    allow(controller).to receive(:table_order).and_return('name ASC')
  end

  describe 'GET #importer_table' do
    before do
      FactoryBot.create(:bulkrax_importer_csv, name: 'Hyc Import')
      FactoryBot.create(:bulkrax_importer_csv, name: 'Hyc Two Import')
      FactoryBot.create(:bulkrax_importer_csv, name: 'Boxy Import')
    end

    context 'when there is a search filter' do
      before do
        allow(controller).to receive(:importer_table_search).and_return(['name ILIKE ?', '%Hyc%'])
      end

      it 'returns the filtered count before pagination is applied' do
        get :importer_table, format: :json

        expect(response).to be_successful

        body = JSON.parse(response.body)

        expect(body['recordsTotal']).to eq(3)
        expect(body['recordsFiltered']).to eq(2)
        expect(body['data'].size).to eq(1)
        expect(body['data'].first['name']).to include('Hyc Import')
      end
    end

    context 'when there is no search filter' do
      before do
        allow(controller).to receive(:importer_table_search).and_return(nil)
      end

      it 'returns the total importer count as the filtered count' do
        get :importer_table, format: :json

        expect(response).to be_successful

        body = JSON.parse(response.body)

        expect(body['recordsTotal']).to eq(3)
        expect(body['recordsFiltered']).to eq(3)
        expect(body['data'].size).to eq(1)
      end
    end
  end
end
