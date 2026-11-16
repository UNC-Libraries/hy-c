# frozen_string_literal: true

module AdvancedSearch
  class MultiSelectFacetComponent < Blacklight::Component
    def initialize(facet_field:, layout: nil)
      @facet_field = facet_field
      @layout = layout == false ? Blacklight::FacetFieldNoLayoutComponent : AdvancedSearch::FacetLayoutComponent
    end

    def render?
      presenters.any? || selected_values.any?
    end

    def presenters
      return [] unless @facet_field.paginator
      return to_enum(:presenters) unless block_given?

      @facet_field.paginator.items.each do |item|
        presenter = @facet_field.facet_field.item_presenter || Blacklight::FacetItemPresenter
        yield presenter.new(item, @facet_field.facet_field, helpers, @facet_field.key, @facet_field.search_state)
      end
    end

    def selected_values
      Array(@facet_field.search_state.params.dig(:f_inclusive, @facet_field.key))
    end

    def extra_values
      selected_values - presenters.map(&:value)
    end
  end
end
