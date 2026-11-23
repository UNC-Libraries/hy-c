# frozen_string_literal: true

module AdvancedSearch
  class MultiSelectFacetComponent < Blacklight::Component
    class LayoutFacetField < SimpleDelegator
      # Suppress the standard "more facets" modal: this component provides
      # scrolling and a non-JavaScript pagination control instead.
      def modal_path
        nil
      end
    end

    def initialize(facet_field:, layout: nil)
      @facet_field = facet_field
      @layout = layout == false ? Blacklight::FacetFieldNoLayoutComponent : Blacklight::FacetFieldComponent
    end

    # Keep the control visible when selected values or a requested fallback
    # page exist, even if the current facet response has no ordinary options.
    def render?
      presenters.any? || selected_values.any? || page.present?
    end

    # Yield presenters for the requested fallback page or the initial facet
    # values. Add selected values missing from that page so they remain visible,
    # removable, and submitted even when their counts are unavailable.
    def presenters
      return to_enum(:presenters) unless block_given?

      items = (page&.dig(:paginator) || @facet_field.paginator)&.items || []
      presenter_class = @facet_field.facet_field.item_presenter || Blacklight::FacetItemPresenter
      item_presenters = items.map do |item|
        presenter_class.new(item, @facet_field.facet_field, helpers, @facet_field.key, @facet_field.search_state)
      end
      missing_values = selected_values - item_presenters.map(&:value)
      missing_values.each do |value|
        item_presenters.unshift(presenter_class.new(value, @facet_field.facet_field, helpers, @facet_field.key, @facet_field.search_state))
      end
      item_presenters.each { |presenter| yield presenter }
    end

    # Read the inclusive selections represented by this multi-select; wrapping
    # the result also handles a missing field without changing its value.
    def selected_values
      Array(@facet_field.search_state.params.dig(:f_inclusive, @facet_field.key))
    end

    # Retrieve the fallback page for this field, or nil when the initial
    # advanced-search facet response should be used.
    def page
      helpers.advanced_facet_page(@facet_field.key)
    end

    # Delegate ordinary layout behavior while hiding the modal link that would
    # otherwise navigate away from the advanced-search selection workflow.
    def layout_facet_field
      LayoutFacetField.new(@facet_field)
    end

    # Expose the endpoint, initial continuation state, and translated messages
    # to Tom Select while preserving the native inclusive-filter form name.
    def select_attributes
      {
        name: "f_inclusive[#{@facet_field.key}][]",
        class: 'advanced-search-multi-select',
        multiple: true,
        aria: { label: @facet_field.label },
        data: {
          placeholder: I18n.t('blacklight.advanced_search.facet_placeholder'),
          page_limit_message: I18n.t('blacklight.advanced_search.facet_page_limit'),
          facet_has_more: @facet_field.paginator&.next_page.present?,
          facet_url: helpers.search_facet_path(id: @facet_field.key, format: :json, advanced_options: '1')
        }
      }
    end

    # Preserve the indexed value for submission and the formatted label for
    # selected-item rendering; mark existing inclusive selections as selected.
    def option_attributes(presenter:)
      {
        value: presenter.value,
        selected: selected_values.include?(presenter.value),
        data: { label: helpers.strip_tags(presenter.label.to_s) }
      }
    end
  end
end
