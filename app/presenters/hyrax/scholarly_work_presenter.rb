# Generated via
#  `rails generate hyrax:work ScholarlyWork`
module Hyrax
  class ScholarlyWorkPresenter < Hyrax::WorkShowPresenter
    delegate :abstract, :advisor, :conference_name, :date_issued, :deposit_record, :doi, :dcmi_type,
             :geographic_subject, to: :solr_document
  end
end
