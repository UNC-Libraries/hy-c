# Generated via
#  `rails generate hyrax:work Dissertation`
module Hyrax
  class DissertationPresenter < Hyrax::WorkShowPresenter
    delegate :degree, :academic_concentration, :graduation_year, :date_published, :advisor,
             :degree_granting_institution, :citation, to: :solr_document
  end
end
