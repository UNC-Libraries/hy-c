# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyc::CatalogSearchBuilder do
  let(:context) { FakeSearchBuilderScope.new }
  let(:builder) { described_class.new(context).with(blacklight_params) }
  let(:solr_params) { Blacklight::Solr::Request.new }
  let(:all_fields_edismax) { CatalogController.blacklight_config.search_fields['all_fields'].clause_params[:edismax] }

  describe '#limit_advanced_search_facets' do
    let(:blacklight_params) { {} }
    let(:controller) { instance_double(CatalogController, action_name: action_name) }

    before do
      allow(builder).to receive(:search_state).and_return(instance_double(Blacklight::SearchState, controller: controller))
      solr_params['f.keyword_sim.facet.limit'] = 6
      solr_params['f.date_issued_isim.facet.limit'] = 6
      builder.limit_advanced_search_facets(solr_params)
    end

    context 'on the advanced search form' do
      let(:action_name) { 'advanced_search' }

      it 'limits multi-select facets to a page but not the date facet' do
        expect(solr_params['f.keyword_sim.facet.limit']).to eq(described_class::ADVANCED_SEARCH_FACET_PAGE_SIZE + 1)
        expect(solr_params['f.date_issued_isim.facet.limit']).to eq(6)
      end
    end

    context 'on search results' do
      let(:action_name) { 'index' }

      it 'leaves ordinary facet limits unchanged' do
        expect(solr_params['f.keyword_sim.facet.limit']).to eq(6)
      end
    end

    context 'for an advanced search facet page request' do
      let(:action_name) { 'facet' }
      let(:blacklight_params) { { advanced_search_facet: '1', 'facet.page': '2' } }

      it 'limits multi-select facets to a page' do
        expect(solr_params['f.keyword_sim.facet.limit']).to eq(described_class::ADVANCED_SEARCH_FACET_PAGE_SIZE + 1)
        expect(solr_params['f.keyword_sim.facet.offset']).to eq(described_class::ADVANCED_SEARCH_FACET_PAGE_SIZE)
      end
    end
  end

  describe '#join_works_from_files' do
    subject(:join_works_from_files) { builder.join_works_from_files(solr_params) }

    context 'with a quoted all_fields basic search' do
      let(:blacklight_params) { { q: '"Doctor of Nursing Practice"', search_field: 'all_fields' } }

      before do
        solr_params[:json] = {
          query: {
            bool: {
              must: [{
                edismax: all_fields_edismax.merge(query: '"Doctor of Nursing Practice"')
              }]
            }
          }
        }
      end

      it 'replaces the all_fields clause with a nested OR query and preserves quoted phrases' do
        join_works_from_files

        clause = solr_params.dig(:json, :query, :bool, :must, 0)

        expect(solr_params[:q]).to be_nil
        expect(solr_params[:defType]).to be_nil
        expect(clause.dig(:bool, :should, 0, :edismax, :query)).to eq '"Doctor of Nursing Practice"'
        expect(clause.dig(:bool, :should, 1)).to include('\\"Doctor of Nursing Practice\\"')
      end
    end

    context 'with an advanced search where all_fields is not the first clause' do
      let(:blacklight_params) do
        {
          search_field: 'advanced',
          clause: {
            '0' => { field: 'creator', query: 'Smith' },
            '1' => { field: 'all_fields', query: 'thesis' }
          }
        }
      end

      before do
        solr_params[:json] = {
          query: {
            bool: {
              must: [
                {
                  edismax: {
                    qf: 'creator_label_tesim',
                    pf: 'creator_label_tesim',
                    query: 'Smith'
                  }
                },
                {
                  edismax: all_fields_edismax.merge(query: 'thesis')
                }
              ]
            }
          }
        }
      end

      it 'preserves the other advanced clauses and rewrites only the all_fields clause' do
        join_works_from_files

        must_clauses = solr_params.dig(:json, :query, :bool, :must)

        expect(must_clauses.first.dig('edismax', 'query')).to eq('Smith')
        expect(must_clauses.first.dig('edismax', 'qf')).to eq('creator_label_tesim')
        expect(must_clauses.first.dig('edismax', 'pf')).to eq('creator_label_tesim')
        expect(must_clauses.second.dig(:bool, :should, 0, :edismax, :query)).to eq('thesis')
        expect(must_clauses.second.dig(:bool, :should, 1)).to include('thesis')
      end
    end

    context 'with an advanced search using an unbalanced quote' do
      let(:blacklight_params) do
        {
          search_field: 'advanced',
          clause: { '0' => { field: 'all_fields', query: 'un"balanced' } }
        }
      end

      before do
        solr_params[:json] = {
          query: {
            bool: {
              must: [{
                edismax: all_fields_edismax.merge(query: 'un"balanced')
              }]
            }
          }
        }
      end

      it 'sanitizes the query before building the nested OR clause' do
        join_works_from_files

        clause = solr_params.dig(:json, :query, :bool, :must, 0)

        expect(clause.dig(:bool, :should, 0, :edismax, :query)).to eq('unbalanced')
        expect(clause.dig(:bool, :should, 1)).to include('unbalanced')
      end
    end
  end

  class FakeSearchBuilderScope
    attr_reader :blacklight_config, :current_ability, :current_user, :params, :repository, :search_state_class

    def initialize(blacklight_config: CatalogController.blacklight_config, current_ability: nil, current_user: nil, params: {}, search_state_class: nil)
      @blacklight_config = blacklight_config
      @current_user = current_user
      @current_ability = current_ability || ::Ability.new(current_user)
      @params = params
      @repository = Blacklight::Solr::Repository.new(blacklight_config)
      @search_state_class = search_state_class
    end
  end
end
