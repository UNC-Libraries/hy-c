# Generated via
#  `rails generate hyrax:work Multimed`
module Hyrax
  class MultimedPresenter < Hyrax::WorkShowPresenter
    delegate :abstract, :dcmi_type, :date_issued, :deposit_record, :doi, :extent, :geographic_subject, :language_label,
             :license_label, :medium, :note, :orcid, :resource_type, :rights_statement_label, to: :solr_document
  end
end
