# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('app/overrides/controllers/hyrax/my/works_controller_override.rb')

RSpec.describe Hyrax::My::WorksController, type: :controller do
  let(:ability) { instance_double(Ability) }
  let(:query_service) { instance_double('query_service') }

  before do
    allow(controller).to receive(:current_ability).and_return(ability)
    allow(Hyrax).to receive(:query_service).and_return(query_service)
  end

  describe '#admin_sets_for_select' do
    context 'when depositable admin sets are available' do
      let(:source_ids) { ['z-admin-set', Hyrax::AdminSetCreateService::DEFAULT_ID, 'a-admin-set'] }
      let(:solr_query_service) { instance_double(Hyrax::SolrQueryService) }
      let(:solr_documents) do
        [
          { 'id' => 'z-admin-set', 'title_tesim' => ['Zeta Admin Set'] },
          { 'id' => Hyrax::AdminSetCreateService::DEFAULT_ID, 'title_tesim' => ['Default Admin Set'] },
          { 'id' => 'a-admin-set', 'title_tesim' => ['Alpha Admin Set'] }
        ]
      end

      before do
        allow(Hyrax::Collections::PermissionsService)
          .to receive(:source_ids_for_deposit)
          .with(ability: ability, source_type: 'admin_set')
          .and_return(source_ids)

        allow(Hyrax::AdminSetCreateService)
          .to receive(:default_admin_set?) do |id:|
            id == Hyrax::AdminSetCreateService::DEFAULT_ID
          end

        allow(Hyrax::SolrQueryService).to receive(:new).and_return(solr_query_service)
        allow(solr_query_service).to receive(:with_ids).with(ids: source_ids).and_return(solr_query_service)
        allow(solr_query_service)
          .to receive(:with_field_pairs)
          .with(
            field_pairs: {
              has_model_ssim: Hyrax::ModelRegistry.admin_set_rdf_representations.join(',')
            },
            type: 'terms'
          )
          .and_return(solr_query_service)
        allow(solr_query_service)
          .to receive(:solr_documents)
          .with(rows: source_ids.length, fl: 'id,title_tesim')
          .and_return(solr_documents)
      end

      it 'builds the select options from Solr without loading admin sets through the query service' do
        expect(query_service).not_to receive(:find_many_by_ids)

        expect(controller.send(:admin_sets_for_select)).to eq(
          [
            ['Default Admin Set', Hyrax::AdminSetCreateService::DEFAULT_ID],
            ['Alpha Admin Set', 'a-admin-set'],
            ['Zeta Admin Set', 'z-admin-set']
          ]
        )
      end
    end

    context 'when there are no depositable admin sets' do
      before do
        allow(Hyrax::Collections::PermissionsService)
          .to receive(:source_ids_for_deposit)
          .with(ability: ability, source_type: 'admin_set')
          .and_return([])
      end

      it 'returns an empty list without querying Solr' do
        expect(Hyrax::SolrQueryService).not_to receive(:new)
        expect(query_service).not_to receive(:find_many_by_ids)

        expect(controller.send(:admin_sets_for_select)).to eq([])
      end
    end
  end
end
