# Generated via
#  `rails generate hyrax:work Dissertation`
module Hyrax
  class DissertationPresenter < Hyrax::WorkShowPresenter
    delegate :author_degree_granted, :author_academic_concentration, :author_graduation_date, :date_published,
             :faculty_advisor_name, :institution, :citation, to: :solr_document
  end
end
