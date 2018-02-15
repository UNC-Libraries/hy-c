# Generated via
#  `rails generate hyrax:work Multimedia`
module Hyrax
  class MultimediaPresenter < Hyrax::WorkShowPresenter
    delegate :abstract, :extent, :genre, :geographic_subject, :note, :resource_type, to: :solr_document
  end
end
