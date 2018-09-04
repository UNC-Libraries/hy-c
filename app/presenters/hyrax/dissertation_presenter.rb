# Generated via
#  `rails generate hyrax:work Dissertation`
module Hyrax
  class DissertationPresenter < Hyrax::WorkShowPresenter
    delegate :abstract, :academic_concentration, :access, :advisor, :affiliation, :affiliation_label, :alternative_title, :date_issued,
             :dcmi_type, :degree, :degree_granting_institution, :deposit_record, :discipline, :doi, :geographic_subject,
             :graduation_year, :note, :place_of_publication, :resource_type, :reviewer, :use, to: :solr_document
  end
end
