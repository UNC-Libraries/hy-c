class RangeLimitCatalogSearchBuilder < Hyrax::CatalogSearchBuilder
  include BlacklightAdvancedSearch::AdvancedSearchBuilder
  include BlacklightRangeLimit::RangeLimitBuilder
  self.default_processor_chain += [
    :add_user_query,
    :add_advanced_parse_q_to_solr,
    :add_advanced_search_to_solr,
    :join_works_from_files
  ]

  # :q param is overwritten by Blacklight advanced search, so add original query back as a different param.
  # This must be the first processor in this processor chain or it will add the wrong :q value
  # Hyrax adds a :user_query param in its default search, so just use that if present
  def add_user_query(solar_parameters)
    return if blacklight_params[:q].blank? || solar_parameters[:user_query]
    solar_parameters[:user_query] = blacklight_params[:q]
  end

  # join from file id to work relationship solrized file_set_ids_ssim for full text searching in advanced search
  # This should always be the last processor in this processor chaing
  def join_works_from_files(solar_parameters)
    return if blacklight_params[:q].blank? || solar_parameters[:user_query].blank?
    solar_parameters[:q] += " _query_:{!join from=#{ActiveFedora.id_field} to=file_set_ids_ssim}{!dismax qf=all_text_timv}\"#{solar_parameters[:user_query]}\""
  end
end