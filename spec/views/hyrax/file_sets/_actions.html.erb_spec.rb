# frozen_string_literal: true
# [hyc-override] only admins may see delete option in fileset action dropdown
require 'rails_helper'

RSpec.describe 'hyrax/file_sets/_actions.html.erb', type: :view do
  let(:solr_document) { double("Solr Doc", id: 'file_set_id') }
  let(:user) { FactoryBot.create(:user) }
  let(:ability) { Ability.new(user) }
  let(:file_set) { Hyrax::FileSetPresenter.new(solr_document, ability) }
  let(:work_solr_document) do
    SolrDocument.new(id: '900', title_tesim: ['My Title'])
  end
  let(:parent_presenter) { Hyrax::WorkShowPresenter.new(work_solr_document, ability) }

  before do
    allow(controller).to receive(:current_ability).and_return(ability)
    allow(file_set).to receive(:parent).and_return(:parent)
    allow(file_set).to receive(:id).and_return('fake')
    assign(:presenter, parent_presenter)
    allow(view).to receive(:workflow_restriction?).and_return(false)
    allow(view).to receive(:can?).with(:edit, file_set.id).and_return(true)
    allow(view).to receive(:can?).with(:destroy, file_set.id).and_return(true)
    allow(view).to receive(:can?).with(:download, file_set.id).and_return(true)
  end

  context 'as an admin' do
    before do
      allow(ability).to receive(:admin?).and_return(true)
      render 'hyrax/file_sets/actions', file_set: file_set
    end
    it 'shows delete action in dropdown' do
      expect(rendered).to have_link("Delete")
    end
  end

  context 'as a regular user' do
    before do
      allow(ability).to receive(:admin?).and_return(false)
      render 'hyrax/file_sets/actions', file_set: file_set
    end
    it 'does not show delete action in dropdown' do
      expect(rendered).not_to have_link("Delete")
    end
  end
end
