# frozen_string_literal: true
module Hyc
  class CatalogSearchBuilder < Hyrax::CatalogSearchBuilder
    include BlacklightRangeLimit::RangeLimitBuilder

    self.default_processor_chain += [
      :join_works_from_files
    ]

    # join from file id to work relationship solrized file_set_ids_ssim for full text searching in advanced search
    # This should always be the last processor in this processor chain.
    # Adds full text searching for :all_fields
    def join_works_from_files(solr_parameters)
      all_fields_value = retrieve_all_fields_query
      return if all_fields_value.blank?

      # JSON query and q parameters are AND-ed together by solr, so we need to remove the JSON query and replace it with a custom combined query to achieve the desired OR behavior
      # Retrieve the JSON query for metadata search
      json_query = solr_parameters.dig(:json, :query, :bool, :must, 0)
      return if json_query.nil? || json_query[:edismax].nil?

      # Extract the metadata search parameters
      qf = json_query[:edismax][:qf]
      pf = json_query[:edismax][:pf]
      query_term = json_query[:edismax][:query]

      # Sanitize the query term from JSON (handles unbalanced quotes)
      query_term = QueryParserHelper.sanitize_query(query_term)

      # Build metadata query using edismax
      metadata_query = "_query_:\"{!edismax qf='#{qf}' pf='#{pf}'}#{query_term}\""

      # Build combined query that includes both metadata search (from JSON query) and file text search
      combined_query = "(#{metadata_query}) OR (#{all_fields_query(all_fields_value)})"
      solr_parameters.delete(:json)
      # Use lucene defType to allow for the OR operator in the combined query
      solr_parameters[:defType] = 'lucene'
      solr_parameters[:q] = combined_query
    end

    def retrieve_all_fields_query
      # Advanced search uses clause params
      if blacklight_params['clause'].present?
        blacklight_params['clause']&.each do |_, entry|
          if entry['field'] == 'all_fields'
            return QueryParserHelper.sanitize_query(entry['query'])
          end
        end
      end

      # Basic search uses q param directly when search_field is all_fields
      if blacklight_params[:search_field] == 'all_fields' && blacklight_params[:q].present?
        return QueryParserHelper.sanitize_query(blacklight_params[:q])
      end

      return nil
    end

    def all_fields_query(all_fields_value)
      " _query_:\"#{join_work_to_file}{!dismax qf=all_text_timv}#{all_fields_value}\""
    end

    def join_work_to_file
      "{!join from=#{ActiveFedora.id_field} to=file_set_ids_ssim}"
    end
  end
end
