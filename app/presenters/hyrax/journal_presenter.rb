# Generated via
#  `rails generate hyrax:work Journal`
module Hyrax
  class JournalPresenter < Hyrax::WorkShowPresenter
    delegate :abstract, :alternative_title, :date_issued, :dcmi_type, :deposit_record, :doi, :extent,
             :geographic_subject, :isbn, :issn, :language_label, :license_label, :note, :orcid, :place_of_publication,
             :rights_statement_label, :table_of_contents, to: :solr_document
  end
end
