# frozen_string_literal: true
# [hyc-override] https://github.com/projectblacklight/blacklight_advanced_search/blob/v8.0.0.alpha2/lib/blacklight_advanced_search/advanced_query_parser.rb
BlacklightAdvancedSearch::QueryParser.module_eval do
  # [hyc-override] removes unbalanced quotes and parentheses from the query
  # borrowed from https://github.com/trln/trln_argon/blob/main/config/initializers/advanced_query_parser.rb
  def process_query(config)
    queries = keyword_queries.map do |clause|
      field = clause[:field]
      query = clause[:query]
      begin
        query = remove_quotes(query) if unbalanced_quotes?(query)
        query = remove_parentheses(query) if unbalanced_parentheses?(query)
        ParsingNesting::Tree.parse(query, config.advanced_search[:query_parser])
                            .to_query(local_param_hash(field, config))
      rescue Parslet::ParseFailed => e
        Rails.logger.warn { "failed to parse the advanced search query (#{query}): #{e.message}" }
        next
      end
    end
    queries.join(" #{keyword_op} ")
  end

  private

  def unbalanced_quotes?(query)
    query.count('"').odd?
  end

  def remove_quotes(query)
    query.delete('"')
  end

  def unbalanced_parentheses?(query)
    query.count('(') != query.count(')')
  end

  def remove_parentheses(query)
    query.gsub(/[()]/, '')
  end
end