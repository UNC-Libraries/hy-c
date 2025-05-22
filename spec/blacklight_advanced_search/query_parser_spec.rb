# frozen_string_literal: true
require 'rails_helper'

RSpec.describe BlacklightAdvancedSearch::QueryParser do
  let(:parser) { described_class.new(search_state, config) }
  let(:search_state) { instance_double('Blacklight::SearchState') }
  let(:clauses) do
    {
      '0' => { field: 'all_fields', query: query1 },
      '1' => { field: 'title', query: query2 }
    }
  end
  let(:query1) { 'test query 1' }
  let(:query2) { 'test query 2' }
  let(:op) { 'AND' }
  let(:config) do
    double('config', advanced_search: {
      query_parser: 'dismax'
    })
  end

  before do
    allow(search_state).to receive(:clause_params).and_return(clauses)
    allow(search_state).to receive_message_chain(:params, :[]).with(:op).and_return(op)
    # Set up stubs for the methods not under test
    allow(parser).to receive(:local_param_hash).and_return({ q: '{!dismax}' })
  end

  describe '#process_query' do
    context 'with balanced quotes' do
      let(:query1) { 'balanced "quotes"' }

      it 'preserves the balanced quotes' do
        result = parser.process_query(config)
        expect(result).to eq('_query_:"{!dismax q={!dismax}}balanced \"quotes\"" AND _query_:"{!dismax q={!dismax}}test query 2"')
      end
    end

    context 'with unbalanced quotes' do
      let(:query1) { 'unbalanced "quote' }

      it 'removes the unbalanced quotes' do
        result = parser.process_query(config)
        expect(result).to eq('_query_:"{!dismax q={!dismax}}unbalanced quote" AND _query_:"{!dismax q={!dismax}}test query 2"')
      end
    end

    context 'when StandardError is raised' do
      let(:query1) { 'parse failure' }

      it 'logs an error' do
        expect(ParsingNesting::Tree).to receive(:parse).twice.and_raise(StandardError.new('standard error'))
        expect(Rails.logger).to receive(:error).twice

        parser.process_query(config)
      end
    end
  end
end
