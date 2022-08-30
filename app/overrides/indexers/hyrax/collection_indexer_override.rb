# frozen_string_literal: true
# [hyc-override] Overriding to add index fields to sort date_created as date_issued (to match works sorting) and title
# https://github.com/samvera/hyrax/blob/v2.9.6/app/indexers/hyrax/collection_indexer.rb
Hyrax::CollectionIndexer.class_eval do
  alias_method :original_generate_solr_document, :generate_solr_document

  # @yield [Hash] calls the yielded block with the solr document
  # @return [Hash] the solr document WITH all changes
  def generate_solr_document
    current_solr_doc = original_generate_solr_document
    current_solr_doc.tap do |solr_doc|
      solr_doc['date_issued_sort_ssi'] = Array(object.date_created).first unless object.date_created.blank?
      solr_doc['title_sort_ssi'] = Array(object.title).first&.downcase unless object.title.blank?
    end
  end
end
