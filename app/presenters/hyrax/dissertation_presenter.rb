# Generated via
#  `rails generate hyrax:work Dissertation`
module Hyrax
  class DissertationPresenter < Hyrax::WorkShowPresenter
    delegate :abstract, :academic_concentration, :access, :advisor, :alternative_title, :date_issued,
             :degree, :degree_granting_institution, :discipline, :doi, :genre, :geographic_subject, :graduation_year,
             :note, :place_of_publication, :resource_type, :reviewer, :use, to: :solr_document
  end
end
