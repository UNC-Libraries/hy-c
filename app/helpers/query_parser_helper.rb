# frozen_string_literal: true
module QueryParserHelper
  module_function
  # Sanitizes a query clause by removing unbalanced quotes and parentheses to prevent parslet errors.
  def sanitize_query(query)
    query = remove_quotes(query) if unbalanced_quotes?(query)
    query = remove_parentheses(query) if unbalanced_parentheses?(query)
    query
  end

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
