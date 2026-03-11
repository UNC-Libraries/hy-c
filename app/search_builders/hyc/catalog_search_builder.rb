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

      # Build the join query for file text
      join_query = all_fields_query(all_fields_value)

      # Check if this is an advanced search (has clause params)
      is_advanced_search = blacklight_params['clause'].present?

      if is_advanced_search
        # Build combined query that includes both metadata search (from JSON query) and file text search (from join query)
        # Retrieve the JSON query for metadata search
        json_query = solr_parameters.dig(:json, :query, :bool, :must, 0)

        if json_query && json_query[:edismax]
          # Extract the metadata search parameters
          qf = json_query[:edismax][:qf]
          pf = json_query[:edismax][:pf]
          query_term = json_query[:edismax][:query]

          # Build metadata query using edismax
          metadata_query = "_query_:\"{!edismax qf='#{qf}' pf='#{pf}'}#{query_term}\""

          # Combine metadata and file text queries with OR
          combined_query = "(#{metadata_query}) OR (#{join_query})"

          # JSON query and q parameters are AND-ed together by the edismax parser, so we need to remove the JSON query and replace with combined query to achieve OR behavior
          solr_parameters.delete(:json)
          solr_parameters[:defType] = 'lucene'
          solr_parameters[:q] = combined_query
        end
      else
        # Basic search - skip join query, just let JSON query search metadata
        # File text search only works in advanced search
        Rails.logger.info 'Basic search - skipping join query, using metadata search only'
      end
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
