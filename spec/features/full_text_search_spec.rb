# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('spec/support/full_text.rb')
include Warden::Test::Helpers

RSpec.describe 'Search the catalog for full text', type: :feature, js: false do
  context "with full text on the solr object" do
    before do
      solr = Blacklight.default_index.connection
      solr.add([FULL_TEXT_WORK, FULL_TEXT_FILE_SET])
      solr.commit
    end

    it "can go to the advanced search page from the home page" do
      visit root_path
      click_link("Advanced search", match: :first)
      expect(page).to have_content('Select "match all" to require all fields.')
    end

    it "can perform a regular search against full text" do
      visit root_path
      fill_in('q', with: 'metalloprotease')
      click_button("Go")
      expect(page).to have_content("Full text search testing")
    end

    it "can do an advanced search against full text" do
      visit '/advanced'
      fill_in('all_fields', with: "metalloprotease")
      click_button('Search')
      expect(page).to have_content("Full text search testing")
    end

    it "can return to the advanced search page after an advanced search" do
      visit '/advanced'
      fill_in('all_fields', with: "metalloprotease")
      click_button('Search')
      expect(page).to have_content("Full text search testing")
      click_link("Advanced search", match: :first)
      expect(page).to have_content('Select "match all" to require all fields.')
    end
  end
end
