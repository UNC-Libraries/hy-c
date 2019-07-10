# Generated via
#  `rails generate hyrax:work Journal`
module Hyrax
  class JournalPresenter < Hyrax::WorkShowPresenter
    delegate :abstract, :admin_note, :alternative_title, :creator_display, :date_issued, :dcmi_type, :deposit_record, :digital_collection,
             :doi, :edition, :extent, :isbn, :issn, :language_label, :license_label, :note, :place_of_publication,
             :rights_statement_label, :series, to: :solr_document
  end
end
