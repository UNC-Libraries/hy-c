# Generated via
#  `rails generate hyrax:work Article`
module Hyrax
  class ArticlePresenter < Hyrax::WorkShowPresenter
    delegate :abstract, :access, :bibliographic_citation, :copyright_date, :creator_display, :date_captured,
             :date_issued, :date_other, :dcmi_type, :deposit_record, :doi, :edition, :extent, :funder,
             :geographic_subject, :issn, :journal_issue, :journal_title, :journal_volume, :language_label,
             :license_label, :note, :page_end, :page_start, :peer_review_status, :place_of_publication, :rights_holder,
             :rights_statement_label, :translator_display, :use, to: :solr_document
  end
end
