# Generated via
#  `rails generate hyrax:work Dissertation`
module Hyrax
  class DissertationPresenter < Hyrax::WorkShowPresenter
    delegate :abstract, :academic_concentration, :academic_department, :access, :advisor, :date_issued, :degree,
             :degree_granting_institution, :discipline, :doi, :format, :genre, :graduation_year,
             :note, :place_of_publication, :record_content_source, :reviewer, to: :solr_document
  end
end
