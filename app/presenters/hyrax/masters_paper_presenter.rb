# Generated via
#  `rails generate hyrax:work MastersPaper`
module Hyrax
  class MastersPaperPresenter < Hyrax::WorkShowPresenter
    delegate :abstract, :academic_concentration, :access, :advisor_display, :creator_display, :date_issued, :dcmi_type,
             :degree, :degree_granting_institution, :deposit_record, :doi, :extent, :geographic_subject,
             :graduation_year, :language_label, :license_label, :note, :reviewer_display, :rights_statement_label, :use,
             to: :solr_document
  end
end
