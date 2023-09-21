# frozen_string_literal: true

module Hyc
  class ConstraintsComponent < Blacklight::ConstraintsComponent
    # Suppress the constraint section if we are viewing the collection browse page
    def render?
      return false if is_collections_pages?
      super
    end

    def is_collections_pages?
      @search_state.params.dig('f', 'human_readable_type_sim')&.at(0) == 'Collection'
    end
  end
end