# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('spec/support/full_text.rb')

RSpec.describe 'Advanced search facets', type: :feature do
  let(:solr) { Blacklight.default_index.connection }
  let(:id_prefix) { "advanced-facet-test-#{SecureRandom.hex(8)}" }
  let(:ids) { (1..55).map { |number| "#{id_prefix}-#{number}" } }
  let(:keyword_select) { 'select[name="f_inclusive[keyword_sim][]"]' }
  let(:keyword_checkboxes) { 'input[type="checkbox"][name="f_inclusive[keyword_sim][]"]' }

  before do
    documents = ids.each_with_index.map do |id, index|
      FULL_TEXT_WORK.merge(
        id: id,
        title_tesim: ["Facet test work #{index + 1}"],
        keyword_sim: ["Facet keyword #{format('%02d', index + 1)}"],
        language_sim: ['http://id.loc.gov/vocabulary/iso639-2/eng'],
        affiliation_label_sim: ['School of Dentistry'],
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

  it 'uses Blacklight checkbox facets and preserves and removes selections without JavaScript' do
    visit '/catalog/advanced'
    expect(page).to have_css(keyword_checkboxes, count: CatalogController.blacklight_config.facet_fields['keyword_sim'].limit)
    expect(page).not_to have_css(keyword_select, visible: true)
    expect(page).not_to have_css(keyword_checkboxes, value: 'Facet keyword 55')
    expect(page).to have_css('.blacklight-keyword_sim .more_facets')
    expect(page).to have_field('range_date_issued_isim_begin')

    find(keyword_checkboxes, value: 'Facet keyword 01').check
    click_button 'Search'
    expect(page).to have_content('Facet test work 1')
    expect(page).not_to have_content('Facet test work 2')

    click_link 'Advanced search', match: :first
    expect(find(keyword_checkboxes, value: 'Facet keyword 01')).to be_checked
    expect(page).not_to have_css('form.advanced input[type=hidden][name^="f_inclusive[keyword_sim]"]', visible: :all)
    find(keyword_checkboxes, value: 'Facet keyword 01').uncheck
    click_button 'Search'
    expect(page).not_to have_content('Facet test work 1')
    expect(page).to have_content('Facet test work 2')
  end

  it 'loads subsequent pages when the dropdown is scrolled', js: true do
    visit '/catalog/advanced'
    page.execute_script(<<~JS)
      window.facetRequests = [];
      const originalFetch = window.fetch;
      window.fetch = function (url, options) {
        window.facetRequests.push(url);
        return originalFetch(url, options);
      };
    JS
    find('.blacklight-keyword_sim .collapse-toggle').click
    wrapper = find(keyword_select, visible: :all).sibling('.ts-wrapper')
    expect(page).not_to have_css('.blacklight-keyword_sim .more_facets', visible: true)
    wrapper.find('.ts-control input').click
    expect(wrapper).to have_css('.option', text: 'Facet keyword 05')
    expect(wrapper).not_to have_css('.option', text: 'Facet keyword 06')
    expect(page.evaluate_script("document.querySelector(arguments[0]).dataset.facetHasMore", keyword_select)).to eq('true')
    expect(page.evaluate_script('window.facetRequests.length')).to eq(0)
    expect(wrapper).to have_css('.loading-more-results')

    page.execute_script(<<~JS, keyword_select)
      const dropdown = document.querySelector(arguments[0]).tomselect.dropdown_content;
      dropdown.dispatchEvent(new WheelEvent('wheel', { deltaY: 100 }));
    JS
    expect(wrapper).to have_css('.option', text: 'Facet keyword 20')
    expect(wrapper).not_to have_css('.option', text: 'Facet keyword 21')
    expect(page.evaluate_script('window.facetRequests.length')).to eq(1)

    page.execute_script(<<~JS, keyword_select)
      const dropdown = document.querySelector(arguments[0]).tomselect.dropdown_content;
      dropdown.scrollTop = dropdown.scrollHeight;
      dropdown.dispatchEvent(new Event('scroll'));
    JS
    expect(wrapper).to have_css('.option', text: 'Facet keyword 40')
    expect(wrapper).to have_css('.loading-more-results')

    page.execute_script(<<~JS, keyword_select)
      const dropdown = document.querySelector(arguments[0]).tomselect.dropdown_content;
      dropdown.scrollTop = dropdown.scrollHeight;
      dropdown.dispatchEvent(new Event('scroll'));
    JS
    expect(wrapper).to have_css('.option', text: 'Facet keyword 55')
    wrapper.find('.option', text: 'Facet keyword 55').click
    expect(wrapper).to have_css('.item', text: 'Facet keyword 55')
  end

  it 'loads more values using keyboard navigation', js: true do
    visit '/catalog/advanced'
    find('.blacklight-keyword_sim .collapse-toggle').click
    wrapper = find(keyword_select, visible: :all).sibling('.ts-wrapper')
    input = wrapper.find('.ts-control input')
    input.click
    expect(wrapper).to have_css('.loading-more-results')
    6.times { input.send_keys(:arrow_down) }
    expect(wrapper).to have_css('.option', text: 'Facet keyword 20')
  end

  it 'does not request more values when a facet fits in the initial limit', js: true do
    visit '/catalog/advanced'
    page.execute_script(<<~JS)
      window.facetRequests = [];
      const originalFetch = window.fetch;
      window.fetch = function (url, options) {
        window.facetRequests.push(url);
        return originalFetch(url, options);
      };
    JS
    find('.blacklight-resource_type_sim .collapse-toggle').click
    wrapper = find('select[name="f_inclusive[resource_type_sim][]"]', visible: :all).sibling('.ts-wrapper')
    wrapper.find('.ts-control input').click
    wrapper.find('.option', text: 'Facet resource').click
    expect(wrapper).to have_css('.item', text: 'Facet resource')
    expect(page.evaluate_script('window.facetRequests.length')).to eq(0)
  end

  it 'finds a formatted language label in the searchable dropdown', js: true do
    visit '/catalog/advanced'
    find('.blacklight-language_sim .collapse-toggle').click
    select = find('select[name="f_inclusive[language_sim][]"]', visible: :all)
    wrapper = select.sibling('.ts-wrapper')
    wrapper.find('.ts-control input').fill_in with: 'english'
    expect(wrapper).to have_css('.option', text: 'English (55)')
  end

  it 'preserves remotely loaded selections when Turbolinks caches the form', js: true do
    visit '/catalog/advanced'
    find('.blacklight-keyword_sim .collapse-toggle').click
    wrapper = find(keyword_select, visible: :all).sibling('.ts-wrapper')
    wrapper.find('.ts-control input').fill_in with: 'Facet keyword 55'
    wrapper.find('.option', text: 'Facet keyword 55').click
    page.execute_script("document.dispatchEvent(new Event('turbolinks:before-cache'))")
    expect(find(keyword_select).value).to include('Facet keyword 55')
    page.execute_script("document.dispatchEvent(new Event('turbolinks:load'))")
    expect(find(keyword_select, visible: :all).sibling('.ts-wrapper')).to have_css('.item', text: 'Facet keyword 55')
  end

  it 'ignores stale responses when the search changes', js: true do
    visit '/catalog/advanced'
    page.execute_script(<<~JS)
      const originalFetch = window.fetch;
      window.fetch = function (url, options) {
        if (url.includes('keyword+01')) {
          window.oldFacetRequested = true;
          return originalFetch(url, options).then(function (response) {
            return new Promise(function (resolve) {
              window.resolveOldFacet = function () { resolve(response); };
              document.body.dataset.oldFacetReady = '1';
            });
          });
        }
        return originalFetch(url, options);
      };
    JS
    find('.blacklight-keyword_sim .collapse-toggle').click
    wrapper = find(keyword_select, visible: :all).sibling('.ts-wrapper')
    input = wrapper.find('.ts-control input')
    input.fill_in with: 'keyword 01'
    expect(page).to have_css('body[data-old-facet-ready="1"]')
    input.fill_in with: 'keyword 55'
    expect(wrapper).to have_css('.option', text: 'Facet keyword 55')
    page.execute_script('window.resolveOldFacet()')
    expect(wrapper).to have_css('.option', text: 'Facet keyword 55')
    expect(wrapper).not_to have_css('.option', text: 'Facet keyword 01')
  end

  it 'stops at the twentieth page and allows a narrower search' do
    extra_ids = (1..401).map { |number| "#{id_prefix}-bulk-#{number}" }
    solr.add(extra_ids.each_with_index.map do |id, index|
      FULL_TEXT_WORK.merge(id: id, keyword_sim: ["facet page limit #{format('%03d', index + 1)}"])
    end)
    solr.commit

    page.driver.get('/catalog/facet/keyword_sim.json', advanced_options: '1', 'facet.page': '20', facet_query: 'facet page limit')
    response = JSON.parse(page.body)
    expect(response['options'].size).to eq(20)
    expect(response['next_page']).to be_nil
    expect(response['limited']).to be(true)

    page.driver.get('/catalog/facet/keyword_sim.json', advanced_options: '1', 'facet.page': '1', facet_query: 'facet page limit 401')
    response = JSON.parse(page.body)
    expect(response['options'].map { |option| option['value'] }).to eq(['facet page limit 401'])
    expect(response['limited']).to be(false)

    page.driver.get('/catalog/facet/keyword_sim.json', advanced_options: '1', 'facet.page': '21')
    expect(page.status_code).to eq(404)
  ensure
    solr.delete_by_id(extra_ids) if extra_ids
    solr.commit
  end

  it 'reports failed facet requests and allows retrying', js: true do
    visit '/catalog/advanced'
    page.execute_script(<<~JS)
      window.originalFacetFetch = window.fetch;
      window.fetch = function () { return Promise.reject(new Error('test failure')); };
    JS
    find('.blacklight-keyword_sim .collapse-toggle').click
    wrapper = find(keyword_select, visible: :all).sibling('.ts-wrapper')
    wrapper.find('.ts-control input').click
    expect(wrapper).to have_css('.loading-more-results')
    page.execute_script(<<~JS, keyword_select)
      document.querySelector(arguments[0]).tomselect.dropdown_content.dispatchEvent(new WheelEvent('wheel', { deltaY: 100 }));
    JS
    expect(page).to have_css('.blacklight-keyword_sim .advanced-facet-load-error', text: 'Could not load')
    page.execute_script('window.fetch = window.originalFacetFetch')
    within('.blacklight-keyword_sim') { click_button 'Try again' }
    expect(page).not_to have_css('.blacklight-keyword_sim .advanced-facet-load-error', visible: true)
    wrapper.find('.ts-control input').click
    expect(wrapper).to have_css('.option', text: 'Facet keyword 20')
  end

  it 'keeps earlier pages when retrying a failed scroll request', js: true do
    visit '/catalog/advanced'
    page.execute_script(<<~JS)
      window.originalFacetFetch = window.fetch;
      window.fetch = function (url, options) {
        return url.includes('facet.page=2') ? Promise.reject(new Error('test failure')) : window.originalFacetFetch(url, options);
      };
    JS
    find('.blacklight-keyword_sim .collapse-toggle').click
    wrapper = find(keyword_select, visible: :all).sibling('.ts-wrapper')
    wrapper.find('.ts-control input').click
    expect(wrapper).to have_css('.loading-more-results')
    page.execute_script(<<~JS, keyword_select)
      document.querySelector(arguments[0]).tomselect.dropdown_content.dispatchEvent(new WheelEvent('wheel', { deltaY: 100 }));
    JS
    expect(wrapper).to have_css('.option', text: 'Facet keyword 20')
    page.execute_script(<<~JS, keyword_select)
      const dropdown = document.querySelector(arguments[0]).tomselect.dropdown_content;
      dropdown.scrollTop = dropdown.scrollHeight;
      dropdown.dispatchEvent(new Event('scroll'));
    JS
    expect(page).to have_css('.blacklight-keyword_sim .advanced-facet-load-error', text: 'Could not load')
    page.execute_script('window.fetch = window.originalFacetFetch')
    within('.blacklight-keyword_sim') { click_button 'Try again' }
    expect(page).not_to have_css('.blacklight-keyword_sim .advanced-facet-load-error', visible: true)
    wrapper.find('.ts-control input').click
    expect(wrapper).to have_css('.option', text: 'Facet keyword 40')
    expect(wrapper).to have_css('.option', text: 'Facet keyword 01')
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
    wrapper = find(keyword_select, visible: :all).sibling('.ts-wrapper')
    wrapper.find('.ts-control input').click
    expect(wrapper).to have_css('.loading-more-results')
    page.execute_script(<<~JS, keyword_select)
      document.querySelector(arguments[0]).tomselect.dropdown_content.dispatchEvent(new WheelEvent('wheel', { deltaY: 100 }));
    JS
    expect(wrapper).to have_css('.option', text: 'Facet keyword 06')
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

end
