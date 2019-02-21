# Generated via
#  `rails generate hyrax:work HonorsThesis`
module Hyrax
  class HonorsThesisPresenter < Hyrax::WorkShowPresenter
    delegate :abstract, :academic_concentration, :access, :advisor_display, :alternative_title, :award,
             :creator_display, :date_issued, :dcmi_type, :degree, :degree_granting_institution, :deposit_record, :doi,
             :extent, :graduation_year, :language_label, :license_label, :note,
             :rights_statement_label, :use, to: :solr_document
  end
end
