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

      result = presenter.send(:retrieve_values, field_config)
      expect(Blacklight::FieldRetriever).to have_received(:new).with(nil, field_config, view_context)
      # Presenter should not process the document if it's nil
      expect(presenter).not_to have_received(:extract_solr_document)
      expect(result).to eq('default_thumbnail')
    end

    it 'updates the thumbnail_path_ss if it needs an update' do
      field_config = double('FieldConfig')
      view_context = double('ViewContext')
      retriever_instance = Blacklight::FieldRetriever.new(nil, nil, nil)
      document_hash = {
        'thumbnail_path_ss' => '/assets/work-default.png',
        'file_set_ids_ssim' => ['file_set_1'],
        'id' => '1'
      }
      solr_doc = SolrDocument.new(document_hash)
      presenter = Blacklight::ThumbnailPresenter.new(solr_doc, view_context, field_config)

      allow(presenter).to receive(:needs_thumbnail_path_update?).and_return(true)
      allow(SolrDocument).to receive(:new).and_return(instance_double(SolrDocument))
      allow(Blacklight::FieldRetriever).to receive(:new).and_return(retriever_instance)
      allow(retriever_instance).to receive(:fetch).and_return('updated_thumbnail')
      allow(Rails.logger).to receive(:info)

      result = presenter.send(:retrieve_values, field_config)
      expect(Rails.logger).to have_received(:info).with('Updated thumbnail_path_ss: /downloads/file_set_1?file=thumbnail for work with id 1')
      expect(SolrDocument).to have_received(:new).with(
        hash_including('thumbnail_path_ss' => '/downloads/file_set_1?file=thumbnail')
      )
      expect(result).to eq('updated_thumbnail')
    end
  end
end
