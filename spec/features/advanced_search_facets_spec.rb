# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('spec/support/full_text.rb')

RSpec.describe 'Advanced search facets', type: :feature do
  let(:solr) { Blacklight.default_index.connection }
  let(:id_prefix) { "advanced-facet-test-#{SecureRandom.hex(8)}" }
  let(:ids) { (1..55).map { |number| "#{id_prefix}-#{number}" } }
  let(:facet) { '.blacklight-keyword_sim' }

  before do
    solr.add(ids.each_with_index.map do |id, index|
      FULL_TEXT_WORK.merge(
        id: id,
        title_tesim: ["Facet test work #{index + 1}"],
        keyword_sim: ["Facet keyword #{format('%02d', index + 1)}"]
      )
    end)
    solr.commit
  end

  after do
    solr.delete_by_id(ids)
    solr.commit
  end

  it 'pages and retains selections without JavaScript' do
    visit '/catalog/advanced'
    fill_in 'All Fields', with: 'Facet test'
    expect(page).to have_css("#{facet} input[type=checkbox]", maximum: 5, visible: :all)
    click_button 'Browse Keyword values'
    check 'Facet keyword 01'
    click_button 'Next'
    check 'Facet keyword 25'
    click_button 'Previous'
    expect(page).to have_checked_field('Facet keyword 01')
    click_button 'Apply selections'
    expect(find_field('All Fields').value).to eq('Facet test')
    expect(page).to have_checked_field('Facet keyword 01', visible: :all)
    expect(page).to have_checked_field('Facet keyword 25', visible: :all)
    click_button 'Search'
    expect(page).to have_content('Facet test work 1')
    expect(page).to have_content('Facet test work 25')
    expect(page).not_to have_content('Facet test work 2')
  end

  it 'keeps selections across modal pages and allows removing them', js: true do
    visit '/catalog/advanced'
    find("#{facet} .collapse-toggle").click
    click_button 'Browse Keyword values'
    within '#blacklight-modal' do
      check 'Facet keyword 01'
      click_button 'Next'
      check 'Facet keyword 25'
      click_button 'Previous'
      expect(page).to have_checked_field('Facet keyword 01')
      click_button 'Apply selections'
    end
    click_button 'Browse Keyword values'
    within '#blacklight-modal' do
      uncheck 'Facet keyword 01'
      click_button 'Next'
      expect(page).to have_checked_field('Facet keyword 25')
      click_button 'Apply selections'
    end
    click_button 'Search'
    expect(page).to have_content('Facet test work 25')
    expect(page).not_to have_content('Facet test work 1')
  end

  it 'rejects more than five selected values without JavaScript and preserves them' do
    visit '/catalog/advanced'
    click_button 'Browse Keyword values'
    6.times { |index| check "Facet keyword #{format('%02d', index + 1)}" }
    click_button 'Apply selections'
    click_button 'Search'
    expect(page).to have_current_path(%r{/catalog/advanced\?})
    expect(page).to have_content('Select no more than 5 values within each facet field.')
    expect(page).to have_css("#{facet} input[type=checkbox]:checked", count: 6, visible: :all)
  end
end
