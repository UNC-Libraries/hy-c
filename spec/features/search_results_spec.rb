# frozen_string_literal: true
require 'rails_helper'
require Rails.root.join('spec/support/oai_sample_solr_documents.rb')
include Warden::Test::Helpers

RSpec.describe 'Search Results', type: :feature, js: false do
  let(:solr) { Blacklight.default_index.connection }

  before do
    solr.delete_by_query('*:*') # delete everything in Solr
    solr.add([SLEEPY_HOLLOW, MYSTERIOUS_AFFAIR, TIME_MACHINE])
    solr.commit
  end

  after do
    solr.delete_by_query('*:*')
    solr.commit
  end

  it 'html tags are stripped from abstract field' do
    visit '/catalog'
    expect(page).to have_content(SLEEPY_HOLLOW[:title_tesim][0])
    expect(page).to have_content(MYSTERIOUS_AFFAIR[:title_tesim][0])
    expect(page).to have_content(TIME_MACHINE[:title_tesim][0])
    expect(page).to have_content("Actual Abstract and another abstract")
  end
end
