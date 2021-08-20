class RangeLimitCatalogSearchBuilder < Hyrax::CatalogSearchBuilder
  include BlacklightAdvancedSearch::AdvancedSearchBuilder
  include BlacklightRangeLimit::RangeLimitBuilder
  self.default_processor_chain += [
    :add_advanced_parse_q_to_solr,
    :add_advanced_search_to_solr,
    :join_works_from_files
  ]

  # join from file id to work relationship solrized file_set_ids_ssim for full text searching in advanced search
  # This should always be the last processor in this processor chain.
  # Adds full text searching for :all_fields
  def join_works_from_files(solr_parameters)
    return unless blacklight_params[:all_fields]
    solr_parameters[:q] += " _query_:\"{!join from=#{ActiveFedora.id_field} to=file_set_ids_ssim}{!dismax qf=all_text_timv}#{blacklight_params[:all_fields]}\""
  end
end