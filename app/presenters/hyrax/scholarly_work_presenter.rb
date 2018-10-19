# Generated via
#  `rails generate hyrax:work ScholarlyWork`
module Hyrax
  class ScholarlyWorkPresenter < Hyrax::WorkShowPresenter
    delegate :abstract, :advisor, :affiliation, :affiliation_label, :conference_name, :date_issued, :dcmi_type,
             :deposit_record, :doi, :geographic_subject, :language_label, :license_label, :orcid, :other_affiliation,
             :rights_statement_label, to: :solr_document
  end
end
