# frozen_string_literal: true
# [hyc-override] https://github.com/projectblacklight/blacklight_advanced_search/blob/v8.0.0.alpha2/lib/blacklight_advanced_search/advanced_search_builder.rb
BlacklightAdvancedSearch::AdvancedSearchBuilder.module_eval do
  def facets_for_advanced_search_form(solr_p)
    # [hyc-override] check if supplied controller has action_name method. Calling it was causing failures in v7 of the blacklight oai-pmh plugin
    # Note: implementing this override with an aliased_method produced infinite recursion
    return unless search_state.controller.respond_to?(:action_name)
    return unless search_state.controller&.action_name == 'advanced_search'

    # ensure empty query is all records, to fetch available facets on entire corpus
    solr_p['q']            = '{!lucene}*:*'
    # explicitly use lucene defType since we are passing a lucene query above (and appears to be required for solr 7)
    solr_p['defType']      = 'lucene'
    # We only care about facets, we don't need any rows.
    solr_p['rows']         = '0'

    # Anything set in config as a literal
    if blacklight_config.advanced_search[:form_solr_parameters]
      solr_p.merge!(blacklight_config.advanced_search[:form_solr_parameters])
    end
  end
end
