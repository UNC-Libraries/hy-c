# frozen_string_literal: true
require 'rails_helper'

RSpec.describe QueryParserHelper do
  describe '.sanitize_query' do
    it 'removes quotes when they are unbalanced' do
      expect(QueryParserHelper.sanitize_query('unbalanced "quote')).to eq('unbalanced quote')
    end

    it 'keeps quotes when they are balanced' do
      expect(QueryParserHelper.sanitize_query('balanced "quote"')).to eq('balanced "quote"')
    end

    it 'removes parentheses when they are unbalanced' do
      expect(QueryParserHelper.sanitize_query('unbalanced (query')).to eq('unbalanced query')
      expect(QueryParserHelper.sanitize_query('unbalanced query)')).to eq('unbalanced query')
    end

    it 'keeps parentheses when they are balanced' do
      expect(QueryParserHelper.sanitize_query('balanced (query)')).to eq('balanced (query)')
    end

    it 'handles both unbalanced quotes and parentheses' do
      expect(QueryParserHelper.sanitize_query('unbalanced "quote with (paren')).to eq('unbalanced quote with paren')
    end
  end
end
