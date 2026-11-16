# frozen_string_literal: true
module Hyc
  class CatalogSearchBuilder < Hyrax::CatalogSearchBuilder
    include BlacklightRangeLimit::RangeLimitBuilder

    self.default_processor_chain += [
      :join_works_from_files
    ]

    # Adds full text searching for :all_fields
    # Rewrites only the advanced-search all_fields clause so it matches either
    # work metadata or joined file full text, while leaving sibling clauses in
    # Blacklight's bool query untouched.
    # This should always be the last processor in this processor chain.
    def join_works_from_files(solr_parameters)
      return if retrieve_all_fields_query.blank?

      bool_query = solr_parameters.dig(:json, :query, :bool)
      return if bool_query.blank?

      # Preserve the surrounding advanced-search bool structure and only rewrite
      # the all_fields clause into: metadata match OR joined file-text match.
      %i[must should must_not].each do |operator|
        next unless bool_query[operator].is_a?(Array)

        bool_query[operator].map! do |clause|
          all_fields_json_clause?(clause) ? build_all_fields_bool_clause(clause) : clause
        end
      end
    end

    # We only need to run the rewrite when the request actually includes an
    # all_fields search, either from advanced search clauses or a basic search.
    def retrieve_all_fields_query
      clauses = blacklight_params['clause'] || blacklight_params[:clause]

      # Advanced search uses clause params
      if clauses.present?
        clauses.each do |_, entry|
          if entry['field'] == 'all_fields'
            return QueryParserHelper.sanitize_query(entry['query'])
          end
        end
      end

      # Basic search uses q param directly when search_field is all_fields
      search_field = blacklight_params[:search_field] || blacklight_params['search_field']
      query = blacklight_params[:q] || blacklight_params['q']

      if search_field == 'all_fields' && query.present?
        return QueryParserHelper.sanitize_query(query)
      end

      nil
    end

    def all_fields_query(all_fields_value)
      "_query_:\"#{join_work_to_file}{!dismax qf=all_text_timv}#{all_fields_value}\""
    end

    def join_work_to_file
      "{!join from=#{ActiveFedora.id_field} to=file_set_ids_ssim}"
    end

    def escape_local_param_query(query)
      query.gsub(/([\\"])/, '\\\\\1')
    end

    # Keeps the outer bool operator from Blacklight intact, but expands the
    # all_fields clause itself into: metadata match OR joined file-text match.
    def build_all_fields_bool_clause(clause)
      edismax = clause[:edismax] || clause['edismax']
      query = QueryParserHelper.sanitize_query(edismax[:query] || edismax['query'])

      {
        bool: {
          should: [
            {
              edismax: {
                # Preserve Blacklight's configured metadata fields for the
                # original all_fields clause.
                qf: edismax[:qf] || edismax['qf'],
                pf: edismax[:pf] || edismax['pf'],
                query: query
              }
            },
            # The file-text side of the OR is still expressed as a local-param
            # query string because it relies on a Solr join.
            all_fields_query(escape_local_param_query(query))
          ]
        }
      }
    end

    # Identify the JSON clause Blacklight built for all_fields by matching the
    # configured edismax fields, rather than assuming a fixed clause position.
    def all_fields_json_clause?(clause)
      edismax = clause[:edismax] || clause['edismax']
      return false unless edismax

      qf = edismax[:qf] || edismax['qf']
      pf = edismax[:pf] || edismax['pf']

      qf == all_fields_edismax[:qf] && pf == all_fields_edismax[:pf]
    end

    # Memoize the configured all_fields edismax so clause matching stays tied to
    # the controller config without repeating the lookup.
    def all_fields_edismax
      @all_fields_edismax ||= CatalogController.blacklight_config.search_fields['all_fields'].clause_params[:edismax]
    end
  end
end
