# Generated via
#  `rails generate hyrax:work Dissertation`
module Hyrax
  class DissertationPresenter < Hyrax::WorkShowPresenter
    delegate :abstract, :academic_concentration, :access, :advisor, :affiliation, :affiliation_label,
             :alternative_title, :date_issued, :dcmi_type, :degree, :degree_granting_institution, :deposit_record, :doi,
             :geographic_subject, :graduation_year, :language_label, :license_label, :note, :orcid,
             :place_of_publication, :resource_type, :reviewer, :rights_statement_label, :use, to: :solr_document
  end
end
