# [hyc-override] Overriding to add index fields to sort date_created as date_issued (to match works sorting) and title
# https://github.com/samvera/hyrax/blob/v2.9.6/app/indexers/hyrax/collection_indexer.rb
Hyrax::CollectionIndexer.class_eval do
  # @yield [Hash] calls the yielded block with the solr document
  # @return [Hash] the solr document WITH all changes
  #
  def generate_solr_document
    super.tap do |solr_doc|
      # Makes Collections show under the "Collections" tab
      solr_doc['generic_type_sim'] = ['Collection']
      solr_doc['visibility_ssi'] = object.visibility
      solr_doc['date_issued_sort_ssi'] = Array(object.date_created).first unless object.date_created.blank?
      solr_doc['title_sort_ssi'] = Array(object.title).first&.downcase unless object.title.blank?

      object.in_collections.each do |col|
        (solr_doc['member_of_collection_ids_ssim'] ||= []) << col.id
        (solr_doc['member_of_collections_ssim'] ||= []) << col.to_s
      end
    end
  end
end
