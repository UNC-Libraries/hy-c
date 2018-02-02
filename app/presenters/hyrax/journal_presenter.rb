# Generated via
#  `rails generate hyrax:work Journal`
module Hyrax
  class JournalPresenter < Hyrax::WorkShowPresenter
    delegate :abstract, :alternate_title, :conference_name, :date_issued, :extent, :genre,
             :geographic_subject, :issn, :note, :place_of_publication, :table_of_contents, to: :solr_document
  end
end
