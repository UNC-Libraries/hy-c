# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CatalogController, type: :controller do
  describe 'Blacklight search result limits' do
    subject(:blacklight_config) { described_class.blacklight_config }

    it 'limits available search result sizes and clamps direct requests' do
      expect(blacklight_config.per_page).to eq([10, 20])
      expect(blacklight_config.default_per_page).to eq(10)
      expect(blacklight_config.max_per_page).to eq(20)
    end
  end
end
