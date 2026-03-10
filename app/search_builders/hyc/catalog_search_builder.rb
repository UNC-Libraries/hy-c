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
        # Advanced search - remove JSON query and use join query only
        # (can't easily OR them with JSON Query DSL)
        solr_parameters.delete(:json)
        solr_parameters.delete(:qf)
        solr_parameters.delete(:pf)
        solr_parameters[:defType] = 'lucene'
        solr_parameters[:q] = join_query
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
