# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Blacklight::FacetFieldPaginationComponent, type: :component do
  let(:facet_field) { double('facet_field') }
  let(:total_unique_facets) { 42 }

  describe '#initialize' do
    context 'when total_unique_facets is provided' do
      it 'sets the facet_field and total_unique_facets attributes' do
        component = Blacklight::FacetFieldPaginationComponent.new(facet_field: facet_field, total_unique_facets: total_unique_facets)

        expect(component.facet_field).to eq(facet_field)
        expect(component.total_unique_facets).to eq(total_unique_facets)
      end
    end

    context 'when total_unique_facets is not provided' do
      it 'sets the total_unique_facets attribute to nil' do
        component = Blacklight::FacetFieldPaginationComponent.new(facet_field: facet_field)

        expect(component.facet_field).to eq(facet_field)
        expect(component.total_unique_facets).to be_nil
      end
    end
  end
end
