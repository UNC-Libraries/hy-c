# Generated via
#  `rails generate hyrax:work ArtWork`
module Hyrax
  class ArtWorkPresenter < Hyrax::WorkShowPresenter
    delegate :doi, :extent, :medium, :license_label, :rights_statement_label, to: :solr_document
  end
end
