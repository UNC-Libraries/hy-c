# Generated via
#  `rails generate hyrax:work ArtWork`
module Hyrax
  class ArtWorkPresenter < Hyrax::WorkShowPresenter
    delegate :doi, :extent, :medium, to: :solr_document
  end
end
