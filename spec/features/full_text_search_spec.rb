# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('spec/support/full_text.rb')
include Warden::Test::Helpers

RSpec.describe 'Search the catalog for full text', type: :feature, js: false do
  let(:solr) { Blacklight.default_index.connection }
  let(:query_term) { 'metalloprotease' }
  let(:target_title) { 'Full text search testing' }

  before do
    solr.add([FULL_TEXT_WORK, FULL_TEXT_FILE_SET])
    solr.commit
  end

  after do
    solr.delete_by_query("id:#{FULL_TEXT_WORK[:id]}")
    solr.delete_by_query("id:#{FULL_TEXT_FILE_SET[:id]}")
    solr.commit
  end

  it "can perform a regular search against full text" do
    visit root_path
    fill_in('q', with: query_term)
    click_button("Go")
    expect(page).to have_content(target_title)
  end

  it "can do an advanced search against full text" do
    visit '/advanced'
    fill_in('all_fields', with: query_term)
    click_button('Search')
    expect(page).to have_content(target_title)
  end

  it "can return to the advanced search page after an advanced search" do
    visit '/advanced'
    fill_in('all_fields', with: query_term)
    click_button('Search')
    expect(page).to have_content(target_title)
    click_link("Advanced search", match: :first)
    expect(page).to have_content('Select "match all" to require all fields.')
  end
end
