require 'rails_helper'

# Overrides default hyrax test file
RSpec.describe 'hyrax/base/_citations.html.erb', type: :view do
  let(:user) { create(:user) }
  let(:object_profile) { ["{\"id\":\"999\"}"] }
  let(:contributor) { ['Frodo'] }
  let(:creator)     { ['Bilbo'] }
  let(:solr_document) do
    SolrDocument.new(
        id: '999',
        object_profile_ssm: object_profile,
        has_model_ssim: ['GenericWork'],
        human_readable_type_tesim: ['Generic Work'],
        contributor_tesim: contributor,
        creator_tesim: creator,
        rights_tesim: ['http://creativecommons.org/licenses/by/3.0/us/']
    )
  end
  let(:ability) { Ability.new(user) }
  let(:params) { { controller: 'hyrax/generals' } }
  let(:presenter) do
    Hyrax::WorkShowPresenter.new(solr_document, ability)
  end
  let(:page) { Capybara::Node::Simple.new(rendered, params: {controller: 'hyrax/generals' }.as_json) }
  # ApplicationController.should.stub(:params){double('params', controller: 'hyrax/data_sets')}

  before do
    allow(controller).to receive(:can?).with(:edit, presenter).and_return(false)
    render 'hyrax/base/citations', presenter: presenter
  end

  # UNC added tests
  context 'when "general" work type' do
    it 'does not appear on page' do
      gets :citations, params: { controller: 'hyrax/generals' }.as_json
      expect(page).to have_no_selector('a#citations')
    end
  end

  context 'when not a "general" work type' do
    it 'appears on page' do
      expect(page).to have_selector('a#citations', count: 1)
    end
  end
end