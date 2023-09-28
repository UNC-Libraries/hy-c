# frozen_string_literal: true
# [hyc-override] https://github.com/projectblacklight/blacklight_advanced_search/blob/v8.0.0.alpha2/lib/blacklight_advanced_search/advanced_search_builder.rb
BlacklightAdvancedSearch::AdvancedSearchBuilder.module_eval do
  alias_method :original_facets_for_advanced_search_form, :facets_for_advanced_search_form
  def facets_for_advanced_search_form(solr_p)
    # [hyc-override] check if supplied controller has action_name method. Calling it was causing failures in v7 of the blacklight oai-pmh plugin
    return unless search_state.controller.respond_to?(:action_name)
    original_facets_for_advanced_search_form(solr_p)
  end
end
