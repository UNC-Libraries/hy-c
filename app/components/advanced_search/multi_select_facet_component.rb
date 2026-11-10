# frozen_string_literal: true

module AdvancedSearch
  class MultiSelectFacetComponent < Blacklight::Component
    def initialize(facet_field:, layout: nil)
      @facet_field = facet_field
      @layout = layout == false ? Blacklight::FacetFieldNoLayoutComponent : Blacklight::FacetFieldComponent
    end

    def render?
      !!@facet_field.paginator
    end

    def presenters
      return [] unless @facet_field.paginator
      return to_enum(:presenters) unless block_given?

      items = @facet_field.paginator.items
      selected_values = Array(@facet_field.search_state.params.dig(:f_inclusive, @facet_field.key))
      selected_items = selected_values.reject do |value|
        items.any? { |item| item.value == value }
      end.map do |value|
        Blacklight::Solr::Response::Facets::FacetItem.new(value: value, label: value)
      end

      (items + selected_items).each do |item|
        presenter = @facet_field.facet_field.item_presenter || Blacklight::FacetItemPresenter
        yield presenter.new(item, @facet_field.facet_field, helpers, @facet_field.key, @facet_field.search_state)
      end
    end

    def select_attributes
      {
        name: "f_inclusive[#{@facet_field.key}][]",
        class: 'advanced-search-multi-select',
        multiple: true,
        aria: { label: @facet_field.label },
        data: {
          placeholder: I18n.t('blacklight.advanced_search.facet_placeholder'),
          facet_key: @facet_field.key,
          facet_url: helpers.search_facet_path(id: @facet_field.key, format: :json),
          facet_load_error: I18n.t('blacklight.advanced_search.facet_load_error', default: 'Facet values could not be loaded.')
        }
      }
    end

    def option_attributes(presenter:)
      {
        value: presenter.value,
        selected: Array(@facet_field.search_state.params.dig(:f_inclusive, @facet_field.key)).include?(presenter.value),
        data: { label: helpers.strip_tags(presenter.label.to_s) }
      }
    end
  end
end
