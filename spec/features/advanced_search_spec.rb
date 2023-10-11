# frozen_string_literal: true
require 'rails_helper'
require Rails.root.join('spec/support/oai_sample_solr_documents.rb')
include Warden::Test::Helpers

RSpec.describe 'Advanced search', type: :feature, js: false do
  let(:solr) { Blacklight.default_index.connection }

  before do
    solr.delete_by_query('*:*') # delete everything in Solr
    solr.add([SLEEPY_HOLLOW, MYSTERIOUS_AFFAIR, BEOWULF, LEVIATHAN, GREAT_EXPECTATIONS, ILIAD, MISERABLES, MOBY_DICK])
    solr.commit
  end

  after do
    solr.delete_by_query('*:*')
    solr.commit
  end

  it 'date range field returns expected results and retains values' do
    visit '/advanced'
    fill_in('range_date_issued_isim_begin', with: '1990')
    fill_in('range_date_issued_isim_end', with: '2020')
    click_button('Search')
    # Verify that only the titles with date issued within the given range are returned
    expect(page).not_to have_content(SLEEPY_HOLLOW[:title_tesim][0])
    expect(page).not_to have_content(MYSTERIOUS_AFFAIR[:title_tesim][0])
    expect(page).not_to have_content(BEOWULF[:title_tesim][0])
    expect(page).not_to have_content(LEVIATHAN[:title_tesim][0])
    expect(page).to have_content(GREAT_EXPECTATIONS[:title_tesim][0])
    expect(page).not_to have_content(ILIAD[:title_tesim][0])
    expect(page).to have_content(MISERABLES[:title_tesim][0])
    expect(page).to have_content(MOBY_DICK[:title_tesim][0])
    # Return to the advanced search and verify that the date range is still present
    click_link('Advanced search', match: :first)
    expect(page).to have_content('Date:1990 to 2020')
    expect(find('#range_date_issued_isim_begin').value).to eq('1990')
    expect(find('#range_date_issued_isim_end').value).to eq('2020')
  end
end
