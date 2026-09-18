# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::FileSetPresenter do
  describe '#fetch_parent_presenter' do
    let(:ability) { instance_double(Ability) }
    let(:file_set_document) { instance_double(SolrDocument, id: 'file-set-id') }
    let(:presenter) { described_class.new(file_set_document, ability) }
    let(:parent_document) { instance_double(SolrDocument, suppressed?: false) }
    let(:parent_presenter) { instance_double(Hyrax::WorkShowPresenter, solr_document: parent_document) }

    it 'uses the presenter factory document for the suppression check' do
      allow(Hyrax::SolrService).to receive(:query).and_return([{ Hyrax.config.id_field => 'parent-id' }])
      allow(ability).to receive(:can?).and_return(false)
      expect(SolrDocument).not_to receive(:find)
      expect(Hyrax::PresenterFactory).to receive(:build_for)
        .with(ids: ['parent-id'], presenter_class: Hyrax::WorkShowPresenter, presenter_args: ability)
        .and_return([parent_presenter])

      expect(presenter.fetch_parent_presenter).to eq(parent_presenter)
    end
  end
end
