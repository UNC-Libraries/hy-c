require 'rails_helper'

RSpec.describe Hyc::ConstraintsComponent, type: :component do
  subject(:component) { described_class.new(**params) }
  let(:rendered) { render_inline(component).to_s }

  let(:page) { Capybara::Node::Simple.new(rendered) }

  let(:params) do
    { search_state: search_state }
  end

  let(:blacklight_config) do
    Blacklight::Configuration.new.configure do |config|
      config.add_facet_field 'some_facet'
    end
  end

  let(:search_state) { Blacklight::SearchState.new(query_params.with_indifferent_access, blacklight_config) }
  let(:query_params) { {} }

  context 'with a query' do
    let(:query_params) { { q: 'some query' } }

    it 'renders a start-over link' do
      expect(page).to have_link 'Start Over', href: '/catalog?locale=en'
    end

    it 'has a header' do
      expect(page).to have_selector('h2', text: 'Search Constraints')
    end

    it 'wraps the output in a div' do
      expect(page).to have_selector('div#appliedParams')
    end

    it 'renders the query' do
      expect(page).to have_selector('.applied-filter.constraint', text: 'some query')
    end
  end

  context 'with a collections type' do
    let(:query_params) { { f: { human_readable_type_sim: ['Collection'] } } }

    it 'does not render a start-over link' do
      expect(page).to_not have_link 'Start Over'
    end

    it 'does not have a header' do
      expect(page).to_not have_selector('h2', text: 'Search Constraints')
    end
  end

  context 'with a different type selected' do
    let(:query_params) { { f: { human_readable_type_sim: ['AdminSet'] } } }

    it 'renders a start-over link' do
      expect(page).to have_link 'Start Over', href: '/catalog?locale=en'
    end

    it 'has a header' do
      expect(page).to have_selector('h2', text: 'Search Constraints')
    end
  end
end