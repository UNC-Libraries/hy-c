# frozen_string_literal: true
require 'rails_helper'
require Rails.root.join('app/repositories/hyc/pooled_solr_repository.rb')

RSpec.describe Hyc::PooledSolrRepository do
  subject(:repository) { described_class.new(CatalogController.blacklight_config) }

  let(:doc_id) { "pooled-solr-repository-spec-#{SecureRandom.hex(6)}" }
  let(:doc_title) { 'Pooled Solr Repository Spec Document' }

  before do
    described_class.instance_variable_set(:@shared_connection, nil)
    repository.connection.delete_by_query("id:#{doc_id}")
    repository.connection.commit
  end

  after do
    repository.connection.delete_by_query("id:#{doc_id}")
    repository.connection.commit
    described_class.instance_variable_set(:@shared_connection, nil)
  end

  describe '#search' do
    it 'returns a successful response from Solr' do
      repository.connection.add([{ id: doc_id, title_tesim: [doc_title] }])
      repository.connection.commit

      response = repository.search(q: "id:#{doc_id}")

      expect(response.documents.count).to eq 1
      expect(response.documents.first.id).to eq doc_id
      expect(response.documents.first['title_tesim']).to eq [doc_title]
    end

    it 'raises an invalid request error for bad lucene syntax' do
      expect do
        repository.search(q: 'title_tesim:(', defType: 'lucene')
      end.to raise_error(Blacklight::Exceptions::InvalidRequest)
    end
  end
end
