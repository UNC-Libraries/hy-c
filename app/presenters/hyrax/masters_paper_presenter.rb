# Generated via
#  `rails generate hyrax:work MastersPaper`
module Hyrax
  class MastersPaperPresenter < Hyrax::WorkShowPresenter
    delegate :academic_concentration, :academic_department, :degree, :degree_granting_institution,
             :graduation_year, :abstract, :advisor, :genre, :access, :extent, :reviewer, :geographic_subject, :note,
             :medium, to: :solr_document
  end
end
