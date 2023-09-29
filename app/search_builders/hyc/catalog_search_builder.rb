# frozen_string_literal: true
module Hyc
  class CatalogSearchBuilder < Hyrax::CatalogSearchBuilder
    include BlacklightAdvancedSearch::AdvancedSearchBuilder
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

      if solr_parameters[:q].present?
        solr_parameters[:q] += all_fields_query(all_fields_value)
      else
        solr_parameters[:q] = all_fields_query(all_fields_value)
      end
    end

    def retrieve_all_fields_query
      blacklight_params['clause']&.each do |_, entry|
        if entry['field'] == 'all_fields'
          return entry['query']
        end
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
