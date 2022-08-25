# [hyc-override] Overriding to add index fields to sort date_created as date_issued (to match works sorting) and title
# https://github.com/samvera/hyrax/blob/v2.9.6/spec/indexers/hyrax/collection_indexer_spec.rb
require 'rails_helper'
# Load the override being tested
require Rails.root.join('app/overrides/indexers/hyrax/collection_indexer_override.rb')

RSpec.describe Hyrax::CollectionIndexer do
  describe '#generate_solr_document' do
    let(:col1title) { 'col1 title' }
    let(:col1created) { '1942-07-08' }
    let(:collection) { Collection.new }
    let(:indexer) { described_class.new(collection) }
    let(:thumbnail) { '/downloads/1234?file=thumbnail' }
    let(:col1id) { 'col1' }
    let(:col1) { instance_double(Collection, id: col1id, to_s: col1title) }
    let(:doc) do
      {
        'generic_type_sim' => ['Collection'],
        'thumbnail_path_ss' => thumbnail,
        'member_of_collection_ids_ssim' => [col1id],
        'member_of_collections_ssim' => [col1title],
        'visibility_ssi' => 'restricted',
        'date_issued_sort_ssi' => col1created,
        'title_sort_ssi' => col1title
      }
    end

    before do
      allow(collection).to receive(:in_collections).and_return([col1])
      allow(collection).to receive(:title).and_return([col1title])
      allow(collection).to receive(:date_created).and_return(col1created)
      allow(Hyrax::ThumbnailPathService).to receive(:call).and_return(thumbnail)
    end

    context 'with custom fields' do
      subject { indexer.generate_solr_document }

      it 'has required fields and custom fields' do
        expect(subject).to match a_hash_including(doc)
      end

      it 'has a custom date issued sort field' do
        expect(subject).to include('date_issued_sort_ssi' => col1created)
      end

      it 'has a custom title sort field' do
        expect(subject).to include('title_sort_ssi' => col1title)
      end
    end
  end
end
