# Generated via
#  `rails generate hyrax:work HonorsThesis`
module Hyrax
  class HonorsThesisPresenter < Hyrax::WorkShowPresenter
    delegate :abstract, :academic_concentration, :access, :advisor, :affiliation, :affiliation_label,
             :alternative_title, :award, :date_issued, :dcmi_type, :degree, :degree_granting_institution,
             :deposit_record, :doi, :extent, :geographic_subject, :graduation_year, :language_label, :license_label,
             :note, :orcid, :rights_statement_label, :url, :use, to: :solr_document
  end
end
