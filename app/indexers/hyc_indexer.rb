class HycIndexer < Hyrax::WorkIndexer
  # This indexes the default metadata. You can remove it if you want to
  # provide your own metadata and indexing.
  include Hyrax::IndexesBasicMetadata

  # Fetch remote labels for based_near. You can remove this if you don't want
  # this behavior
  include Hyrax::IndexesLinkedMetadata

  # Uncomment this block if you want to add custom indexing behavior:
  def generate_solr_document
    super.tap do |solr_doc|
      solr_doc['date_created_tesim'] = Hyc::EdtfConvert.convert_from_edtf(object.date_created) unless object.date_created.blank?
      solr_doc['date_issued_tesim'] = Array(object.date_issued).map {|date| Hyc::EdtfConvert.convert_from_edtf(date)} unless object.date_issued.blank?
    end
  end
end