# frozen_string_literal: true
# [hyc-override] https://github.com/projectblacklight/blacklight/blob/v7.33.1/app/components/blacklight/facet_field_pagination_component.rb
Blacklight::FacetFieldPaginationComponent.class_eval do
  attr_reader :facet_field, :total_unique_facets
  def initialize(facet_field:, total_unique_facets: nil)
    @facet_field = facet_field
    # Integrate total unique facets as an attribute for pagination
    @total_unique_facets = total_unique_facets
  end
end
