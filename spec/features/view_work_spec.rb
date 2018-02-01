# Generated via
#  `rails generate hyrax:work Work`
require 'rails_helper'
include Warden::Test::Helpers

# NOTE: If you generated more than one work, you have to set "js: true"
RSpec.feature 'View a Work', js: false do
  context 'not logged in' do
    scenario do
      visit '/'
      fill_in "search-field-header", with: 'Alice'
      click_button 'search-submit-header'

      expect(page).to have_content "Alice's Adventures in Wonderland"

      click_link "Alice's Adventures in Wonderland"

      expect(page).to have_content "Alice's Adventures in Wonderland"
      expect(page).to have_content 'Abstract'
      expect(page).to have_content 'Items'
    end
  end
end
