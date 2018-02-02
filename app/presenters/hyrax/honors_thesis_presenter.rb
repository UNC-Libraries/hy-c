# Generated via
#  `rails generate hyrax:work HonorsThesis`
module Hyrax
  class HonorsThesisPresenter < Hyrax::WorkShowPresenter
    delegate :abstract, :affiliation, :academic_concentration, :access, :advisor, :degree,
             :degree_granting_institution, :genre, :graduation_year, :honors_level, :note, to: :solr_document
  end
end
