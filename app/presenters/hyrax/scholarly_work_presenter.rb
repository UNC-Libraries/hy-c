# Generated via
#  `rails generate hyrax:work ScholarlyWork`
module Hyrax
  class ScholarlyWorkPresenter < Hyrax::WorkShowPresenter
    delegate :abstract, :advisor_display, :conference_name, :creator_display, :date_issued, :dcmi_type, :deposit_record,
             :doi, :geographic_subject, :language_label, :license_label, :rights_statement_label, to: :solr_document
  end
end
