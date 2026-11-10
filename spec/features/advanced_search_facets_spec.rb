# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('spec/support/full_text.rb')

RSpec.describe 'Advanced search facets', type: :feature do
  let(:solr) { Blacklight.default_index.connection }
  let(:id_prefix) { "advanced-facet-test-#{SecureRandom.hex(8)}" }
  let(:ids) { (1..55).map { |number| "#{id_prefix}-#{number}" } }
  let(:keyword_select) { 'select[name="f_inclusive[keyword_sim][]"]' }

  before do
    documents = ids.each_with_index.map do |id, index|
      FULL_TEXT_WORK.merge(
        id: id,
        title_tesim: ["Facet test work #{index + 1}"],
        keyword_sim: ["Facet keyword #{format('%02d', index + 1)}"],
        creator_label_sim: ['Facet creator'],
        resource_type_sim: ['Facet resource'],
        subject_sim: ['Facet subject'],
        edition_sim: ['Facet version'],
        advisor_label_sim: ['Facet advisor']
      )
    end
    solr.add(documents)
    solr.commit
  end

  after do
    solr.delete_by_id(ids)
    solr.commit
  end

  it 'loads values when a facet opens and preserves and removes inclusive selections', js: true do
    visit '/catalog/advanced'
    select_element = find(keyword_select, visible: :all)
    expect(select_element).to have_css('option', count: 0, visible: :all)
    creator_select = find('select[name="f_inclusive[creator_label_sim][]"]', visible: :all)
    expect(creator_select).to have_css('option', count: 0, visible: :all)
    expect(page).not_to have_css('.blacklight-keyword_sim .more_facets')
    expect(page).to have_field('range_date_issued_isim_begin')

    find('.blacklight-keyword_sim .collapse-toggle').click
    expect(select_element).to have_css('option', minimum: 50, visible: :all)
    expect(select_element).not_to have_css('option', text: 'Facet keyword 55 (1)', visible: :all)
    expect(creator_select).to have_css('option', count: 0, visible: :all)
    select_element.find('option', text: 'Facet keyword 01 (1)', visible: :all).select_option
    select_element.find('option', text: 'Facet keyword 50 (1)', visible: :all).select_option
    click_button 'Search'
    expect(page).to have_content('Facet test work 1')
    expect(page).to have_content('Facet test work 50')
    expect(page).not_to have_content('Facet test work 51')

    click_link 'Advanced search', match: :first
    expect(find(keyword_select, visible: :all).value).to match_array(['Facet keyword 01', 'Facet keyword 50'])
    expect(page).not_to have_css('form.advanced input[type=hidden][name^="f_inclusive[keyword_sim]"]', visible: :all)
    find(keyword_select, visible: :all).find('option', text: 'Facet keyword 01 (1)', visible: :all).unselect_option
    click_button 'Search'
    expect(page).not_to have_content('Facet test work 1')
    expect(page).to have_content('Facet test work 50')
  end

  it 'offers a searchable dropdown and retains values beyond the first 50 options', js: true do
    visit '/catalog/advanced'
    find('.blacklight-keyword_sim .collapse-toggle').click
    expect(page).to have_css('.ts-wrapper', visible: :all)
    select_element = find(keyword_select, visible: :all)
    wrapper = select_element.sibling('.ts-wrapper')
    expect(wrapper.find('[role=combobox]')['aria-label']).to eq(select_element['aria-label'])
    wrapper.find('.ts-control input').click
    dropdown = wrapper.find('.ts-dropdown-content')
    page.execute_script('arguments[0].scrollTop = arguments[0].scrollHeight; arguments[0].dispatchEvent(new Event("scroll"));', dropdown)
    expect(wrapper).to have_css('.option', text: 'Facet keyword 55')
    wrapper.find('.option', text: 'Facet keyword 55').click
    expect(wrapper).to have_css('.item', text: 'Facet keyword 55')
    click_button 'Search'
    expect(page).to have_content('Facet test work 55')

    click_link 'Advanced search', match: :first
    find('.blacklight-keyword_sim .collapse-toggle').click
    expect(find(keyword_select, visible: :all).sibling('.ts-wrapper')).to have_css('.item', text: 'Facet keyword 55')
  end

  it 'explains the existing five-field limit before submitting', js: true do
    visit '/catalog/advanced'
    {
      'resource_type_sim' => 'Facet resource',
      'creator_label_sim' => 'Facet creator',
      'keyword_sim' => 'Facet keyword 01',
      'subject_sim' => 'Facet subject',
      'advisor_label_sim' => 'Facet advisor',
      'edition_sim' => 'Facet version'
    }.each do |field, value|
      find(".blacklight-#{field} .collapse-toggle").click
      select = find("select[name='f_inclusive[#{field}][]']", visible: :all)
      expect(select).to have_css('option', text: value, visible: :all)
      page.execute_script(
        'document.querySelector(arguments[0]).tomselect.addItem(arguments[1])',
        "select[name='f_inclusive[#{field}][]']", value
      )
    end

    click_button 'Search'
    expect(page).to have_current_path('/catalog/advanced')
    expect(page).to have_css('.advanced-search-facet-error', text: 'no more than 5 facet fields')
  end

  it 'blocks more than five values in one facet and allows submission after removing one', js: true do
    visit '/catalog/advanced'
    find('.blacklight-keyword_sim .collapse-toggle').click
    6.times do |index|
      page.execute_script(
        'document.querySelector(arguments[0]).tomselect.addItem(arguments[1])',
        keyword_select, "Facet keyword #{format('%02d', index + 1)}"
      )
    end

    click_button 'Search'
    expect(page).to have_current_path('/catalog/advanced')
    expect(page).to have_css('.advanced-search-facet-value-error', text: 'no more than 5 values')
    expect(page).not_to have_css('.advanced-search-facet-error')

    page.execute_script('document.querySelector(arguments[0]).tomselect.removeItem(arguments[1])', keyword_select, 'Facet keyword 06')
    click_button 'Search'
    expect(page).to have_current_path(%r{/catalog\?})
    expect(page).to have_content('Facet test work 1')
    expect(page).to have_content('Facet test work 5')
    expect(page).not_to have_content('Facet test work 6')
  end

  it 'preserves selections rejected by the server after lazy loading', js: true do
    visit '/catalog/advanced'
    find('.blacklight-keyword_sim .collapse-toggle').click
    select = find(keyword_select, visible: :all)
    expect(select).to have_css('option', minimum: 50, visible: :all)
    fill_in('All Fields', with: 'test')
    6.times do |index|
      select.find('option', text: "Facet keyword #{format('%02d', index + 1)} (1)", visible: :all).select_option
    end
    page.execute_script("document.querySelector('form.advanced').addEventListener('submit', event => event.stopImmediatePropagation(), true)")
    click_button 'Search'

    expect(page).to have_current_path(%r{/catalog/advanced\?})
    expect(page).to have_content('Select no more than 5 values within each facet field.')
    expect(find(keyword_select, visible: :all).value.size).to eq(6)
    expect(find_field('All Fields').value).to eq('test')
  end
end
