# frozen_string_literal: true
require 'rails_helper'
require Rails.root.join('app/overrides/presenters/blacklight/thumbnail_presenter_override.rb')

RSpec.describe Blacklight::ThumbnailPresenter do
  describe '#retrieve_values' do
    it 'does not attempt to process a solr document if it is nil' do
      # Mock field config and view context
      field_config = double('FieldConfig')
      view_context = double('ViewContext')
      presenter = Blacklight::ThumbnailPresenter.new(nil, view_context, field_config)

      retriever_instance = Blacklight::FieldRetriever.new(nil, nil, nil)
      allow(Blacklight::FieldRetriever).to receive(:new).and_return(retriever_instance)
      allow(retriever_instance).to receive(:fetch).and_return('default_thumbnail')
      allow(presenter).to receive(:extract_solr_document)

      presenter.send(:retrieve_values, field_config)
      expect(Blacklight::FieldRetriever).to have_received(:new).with(nil, field_config, view_context)
      # Presenter should not process the document if it's nil
      expect(presenter).not_to have_received(:extract_solr_document)
    end
  end
end
