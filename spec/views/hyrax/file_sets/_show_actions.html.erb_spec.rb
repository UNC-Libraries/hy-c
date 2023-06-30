# frozen_string_literal: true
# [hyc-override] only admins may view delete filesets button
require 'rails_helper'

RSpec.describe 'hyrax/file_sets/_show_actions.html.erb', type: :view do
  let(:user) { FactoryBot.create(:user) }
  let(:object_profile) { ["{'id':'999'}"] }
  let(:contributor) { ['Frodo'] }
  let(:creator)     { ['Bilbo'] }
  let(:solr_document) do
    SolrDocument.new(
      id: '999',
      object_profile_ssm: object_profile,
      has_model_ssim: ['FileSet'],
      human_readable_type_tesim: ['File'],
      contributor_tesim: contributor,
      creator_tesim: creator,
      rights_tesim: ['http://creativecommons.org/licenses/by/3.0/us/']
    )
  end
  let(:decorated_solr_document) { Hyrax::SolrDocument::OrderedMembers.decorate(solr_document) }
  let(:ability) { Ability.new(user) }
  let(:presenter) do
    Hyrax::WorkShowPresenter.new(solr_document, ability)
  end
  let(:page) { Capybara::Node::Simple.new(rendered) }

  before do
    allow(controller).to receive(:current_ability).and_return(ability)
    allow(presenter).to receive(:editor?).and_return(true)
    allow(view).to receive(:workflow_restriction?).and_return(false)
    assign(:presenter, presenter)
  end

  context 'as an admin' do
    before do
      allow(ability).to receive(:admin?).and_return(true)
      view.lookup_context.view_paths.push 'app/views/hyrax/base'
      render
    end

    it 'shows delete button' do
      expect(page).to have_link('Delete This File')
    end
  end

  context 'as a regular user' do
    before do
      allow(ability).to receive(:admin?).and_return(false)
      view.lookup_context.view_paths.push 'app/views/hyrax/base'
      render
    end

    it 'does not show delete button' do
      expect(page).not_to have_link('Delete This File')
    end
  end
end
