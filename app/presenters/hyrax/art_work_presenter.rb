# Generated via
#  `rails generate hyrax:work Artwork`
module Hyrax
  class ArtworkPresenter < Hyrax::WorkShowPresenter
    delegate :doi, :extent, :medium, :license_label, :rights_statement_label, to: :solr_document
  end
end
