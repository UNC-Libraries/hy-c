# frozen_string_literal: true

require 'rails_helper'
include Warden::Test::Helpers

RSpec.describe 'Search the catalog for full text', type: :feature, js: false do
  before do
    solr = Blacklight.default_index.connection
    solr.add(
      id: "1",
      has_model_ssim: ['Article'],
      title_tesim: ["My first title"],
      visibility_ssi: "open",
      read_access_group_ssim: ["public"],
      all_text_timv: "purple monkey dishwasher"
    )
    solr.commit
  end

  it "can go to the advanced search page from the home page" do
    visit root_path
    click_link("Advanced search", match: :first)
    expect(page).to have_content('Select "match all" to require all fields.')
  end

  it "can perform a regular search against full text" do
    visit root_path
    fill_in('q', with: 'monkey')
    click_button("Go")
    expect(page).to have_content("My first title")
  end

  it "can do an advanced search against full text" do
    visit '/advanced'
    fill_in('all_fields', with: "monkey")
    click_button('Search')
    expect(page).to have_content("My first title")
  end

  it "can return to the advanced search page after an advanced search" do
    visit '/advanced'
    fill_in('all_fields', with: "monkey")
    click_button('Search')
    expect(page).to have_content("My first title")
    click_link("Advanced search", match: :first)
    expect(page).to have_content('Select "match all" to require all fields.')
  end

  context "as a logged in user" do
    let(:user) { FactoryBot.create(:user) }
    before do
      login_as user
    end

    it "can do an advanced search and return to the advanced search page" do
      visit '/advanced'
      fill_in('all_fields', with: "monkey")
      click_button('Search')
      expect(page).to have_content("My first title")
      click_link("Advanced search", match: :first)
      expect(page).to have_content('Select "match all" to require all fields.')
    end
  end
end
