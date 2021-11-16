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
      solr_doc['date_issued_tesim'] = Array(object.date_issued).map { |date| Hyc::EdtfConvert.convert_from_edtf(date) } unless object.date_issued.blank?
      solr_doc['date_issued_edtf_tesim'] = Array(object.date_issued) unless object.date_issued.blank?
      solr_doc['date_issued_isim'] = Array(object.date_issued).map { |date| Hyc::EdtfYearIndexer.index_dates(date) }.flatten unless object.date_issued.blank?
      solr_doc['date_issued_sort_ssi'] = Array(object.date_issued).first unless object.date_issued.blank?
      solr_doc['title_sort_ssi'] = Array(object.title).first.downcase unless object.title.blank?
    end
  end
end
