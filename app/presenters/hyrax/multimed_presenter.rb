# Generated via
#  `rails generate hyrax:work Multimed`
module Hyrax
  class MultimedPresenter < Hyrax::WorkShowPresenter
    delegate :abstract, :deposit_record, :doi, :extent, :dcmi_type, :geographic_subject, :note, :resource_type,
             to: :solr_document
  end
end
