# Generated via
#  `rails generate hyrax:work Multimed`
module Hyrax
  class MultimedPresenter < Hyrax::WorkShowPresenter
    delegate :abstract, :dcmi_type, :deposit_record, :doi, :extent, :geographic_subject, :medium, :note, :resource_type,
             to: :solr_document
  end
end
