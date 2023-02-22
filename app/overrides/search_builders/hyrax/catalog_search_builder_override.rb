# frozen_string_literal: true
# https://github.com/samvera/hyrax/blob/hyrax-v3.5.0/app/search_builders/hyrax/catalog_search_builder.rb
Hyrax::CatalogSearchBuilder.class_eval do
  include BlacklightAdvancedSearch::AdvancedSearchBuilder
  include BlacklightRangeLimit::RangeLimitBuilder

  # [hyc-override] add advanced search methods to catalog builder
  self.default_processor_chain += [
    :add_advanced_parse_q_to_solr,
    :add_advanced_search_to_solr
  ]
end
