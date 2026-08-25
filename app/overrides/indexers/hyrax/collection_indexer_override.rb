# frozen_string_literal: true
# [hyc-override] Overriding to add index fields to sort date_created as date_issued (to match works sorting) and title
# https://github.com/samvera/hyrax/blob/v2.9.6/app/indexers/hyrax/collection_indexer.rb
module CollectionIndexerOverride
  def generate_solr_document
    super.tap do |solr_doc|
      solr_doc['date_issued_sort_ssi'] =
        Array(object.date_created).first unless object.date_created.blank?

      solr_doc['title_sort_ssi'] =
        Array(object.title).first&.downcase unless object.title.blank?
    end
  end
end
Hyrax::CollectionIndexer.prepend(CollectionIndexerOverride)
