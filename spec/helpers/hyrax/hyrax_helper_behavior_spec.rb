# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('app/overrides/helpers/hyrax/hyrax_helper_behavior_override.rb')

RSpec.describe Hyrax::HyraxHelperBehavior, type: :helper do
  let(:ability) { instance_double(Ability) }

  before do
    allow(Flipflop).to receive(:assign_admin_set?).and_return(true)
  end

  describe '#available_admin_sets_for_creating_works' do
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

      it 'builds select options from Solr without loading admin sets through the query service' do
        expect(Hyrax).not_to receive(:query_service)

        expect(helper.available_admin_sets_for_creating_works(ability: ability)).to eq(
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
        expect(Hyrax).not_to receive(:query_service)

        expect(helper.available_admin_sets_for_creating_works(ability: ability)).to eq([])
      end
    end
  end
end
