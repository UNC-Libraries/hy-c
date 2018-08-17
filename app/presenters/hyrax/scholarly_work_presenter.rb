# Generated via
#  `rails generate hyrax:work ScholarlyWork`
module Hyrax
  class ScholarlyWorkPresenter < Hyrax::WorkShowPresenter
    delegate :abstract, :advisor, :affiliation, :conference_name, :date_issued, :dcmi_type, :deposit_record, :doi,
             :geographic_subject, :orcid, :other_affiliation, to: :solr_document
  end
end
