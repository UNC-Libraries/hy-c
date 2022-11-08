# frozen_string_literal: true

# [hyc-override] updating expected results for default splitting

require 'rails_helper'
require Rails.root.join('app/overrides/matchers/bulkrax/application_matcher_override.rb')

module Bulkrax
  RSpec.describe ApplicationMatcher do
    describe 'handling the split argument' do
      it 'default split' do
        matcher = ApplicationMatcher.new(split: true)
        result = matcher.result(nil, ' hey ; how : are | you')
        expect(result).to eq(['hey', 'how : are', 'you'])
      end

      it 'custom regex split' do
        matcher = ApplicationMatcher.new(split: /\s*[;]\s*/)
        result = matcher.result(nil, ' hey ; how : are | you')
        expect(result).to eq(['hey', 'how : are | you'])
      end

      it 'no split' do
        matcher = ApplicationMatcher.new(split: false)
        result = matcher.result(nil, ' hey ; how : are | you')
        expect(result).to eq('hey ; how : are | you')
      end

      it 'custom split' do
        matcher = ApplicationMatcher.new(split: '\|')
        result = matcher.result(nil, ' hey ; how : are | you')
        expect(result).to eq(['hey ; how : are', 'you'])
      end
    end
  end
end
