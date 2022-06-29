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
    return if blacklight_params[:all_fields].blank?

    if solr_parameters[:q].present?
      solr_parameters[:q] += all_fields_query
    else
      solr_parameters[:q] = all_fields_query
    end
  end

  def all_fields_query
    " _query_:\"#{join_work_to_file}{!dismax qf=all_text_timv}#{blacklight_params[:all_fields]}\""
  end

  def join_work_to_file
    "{!join from=#{ActiveFedora.id_field} to=file_set_ids_ssim}"
  end
end
