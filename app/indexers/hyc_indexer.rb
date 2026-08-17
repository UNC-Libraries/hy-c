# frozen_string_literal: true
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
      unless object.date_issued.blank?
        solr_doc['date_issued_tesim'] = Array(object.date_issued).map do |date|
          Hyc::EdtfConvert.convert_from_edtf(date, locale: I18n.default_locale)
        end
        solr_doc['date_issued_edtf_tesim'] = Array(object.date_issued)
        solr_doc['date_issued_isim'] = Array(object.date_issued).map do |date|
          Hyc::EdtfYearIndexer.index_dates(date, locale: I18n.default_locale)
        end.flatten
        solr_doc['date_issued_sort_ssi'] = Array(object.date_issued).first
      end

      solr_doc['title_sort_ssi'] = Array(object.title).first.downcase unless object.title.blank?
    end
  end
end
