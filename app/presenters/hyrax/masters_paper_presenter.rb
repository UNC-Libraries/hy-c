# Generated via
#  `rails generate hyrax:work MastersPaper`
module Hyrax
  class MastersPaperPresenter < Hyrax::WorkShowPresenter
    delegate :author_degree_granted, :author_graduation_date, :date_published, :faculty_advisor_name, to: :solr_document
  end
end
