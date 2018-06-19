# Generated via
#  `rails generate hyrax:work MastersPaper`
module Hyrax
  class MastersPaperPresenter < Hyrax::WorkShowPresenter
    delegate :abstract, :academic_concentration, :access, :advisor, :date_issued, :degree,
             :degree_granting_institution, :extent, :genre, :geographic_subject, :graduation_year, :medium, :note,
             :reviewer, :use, to: :solr_document
  end
end
