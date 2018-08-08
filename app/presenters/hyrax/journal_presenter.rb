# Generated via
#  `rails generate hyrax:work Journal`
module Hyrax
  class JournalPresenter < Hyrax::WorkShowPresenter
    delegate :abstract, :alternative_title, :date_issued, :dcmi_type, :deposit_record, :doi, :extent,
             :geographic_subject, :issn, :note, :place_of_publication, :table_of_contents, to: :solr_document
  end
end
