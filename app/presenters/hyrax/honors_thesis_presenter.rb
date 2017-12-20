# Generated via
#  `rails generate hyrax:work HonorsThesis`
module Hyrax
  class HonorsThesisPresenter < Hyrax::WorkShowPresenter
    delegate :abstract, :academic_department, :academic_concentration, :advisor, :degree,
             :degree_granting_institution, :genre, :graduation_year, :honors_level, :note, to: :solr_document
  end
end
