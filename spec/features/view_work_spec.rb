# Generated via
#  `rails generate hyrax:work Work`
require 'rails_helper'
include Warden::Test::Helpers

# NOTE: If you generated more than one work, you have to set "js: true"
RSpec.feature 'View a Work', js: false do
  context 'not logged in' do
    before do
      Article.create!(
        creator: ['Carroll, Lewis'],
        depositor: "admin",
        label: "Alice's Adventures in Wonderland",
        title: ["Alice's Adventures in Wonderland"],
        date_created: "2017-10-02T15:38:56Z",
        date_modified: "2017-10-02T15:38:56Z",
        contributor: ['Smith, Jennifer'],
        description: 'Abstract',
        related_url: ['http://dx.doi.org/10.1186/1753-6561-3-S7-S87'],
        publisher: ['Project Gutenberg'],
        resource_type: ['Book'],
        language: ['http://id.loc.gov/vocabulary/iso639-2/eng'],
        language_label: ['English'],
        rights_statement: 'http://www.europeana.eu/portal/rights/rr-r.html',
        visibility: "open"
      )
    end
    scenario do
      visit '/'
      fill_in "search-field-header", with: 'Alice'
      click_button 'search-submit-header'

      expect(page).to have_content "Alice's Adventures in Wonderland"

      click_link("Alice's Adventures in Wonderland", match: :first)

      expect(page).to have_content "Alice's Adventures in Wonderland"
      expect(page).to have_content 'Items'
    end
  end
end
