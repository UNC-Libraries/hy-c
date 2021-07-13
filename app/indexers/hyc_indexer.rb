class HycIndexer < Hyrax::WorkIndexer
  # This indexes the default metadata. You can remove it if you want to
  # provide your own metadata and indexing.
  include Hyrax::IndexesBasicMetadata

  # Fetch remote labels for based_near. You can remove this if you don't want
  # this behavior
  include Hyrax::IndexesLinkedMetadata

  MAX_CHARACTERS = 3000

  # Uncomment this block if you want to add custom indexing behavior:
  def generate_solr_document
    super.tap do |solr_doc|
      solr_doc['date_issued_tesim'] = Array(object.date_issued).map {|date| Hyc::EdtfConvert.convert_from_edtf(date)} unless object.date_issued.blank?
      solr_doc['date_issued_edtf_tesim'] = Array(object.date_issued) unless object.date_issued.blank?
      solr_doc['date_issued_isim'] =  Array(object.date_issued).map {|date| Hyc::EdtfYearIndexer.index_dates(date)}.flatten unless object.date_issued.blank?
      solr_doc['date_issued_sort_ssi'] = Array(object.date_issued).first unless object.date_issued.blank?
      solr_doc['title_sort_ssi'] = Array(object.title).first.downcase unless object.title.blank?
      solr_doc['all_text_extracted_timv'] = full_text_extract(object)
    end
  end

  def full_text_extract(object)
    object.file_sets.map do |file_set|
      begin
        full_text = file_set.to_solr['all_text_timv']
        full_text[0...MAX_CHARACTERS] unless full_text.blank?
      rescue ActiveTriples::UndefinedPropertyError => e
        # Per OSU, https://github.com/osulp/Scholars-Archive/blob/55f49f1198d8c845f24e1bd4948050b797f19934/app/indexers/default_work_indexer.rb
        # If the work hasn't finished saving or populating the first time on initial deposit, #file_sets may not be ready.
        # Skip saving extracted text this time and wait for the work to save again during deposit.
        nil
      end
    end
  end
end