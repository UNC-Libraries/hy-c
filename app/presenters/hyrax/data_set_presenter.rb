# Generated via
#  `rails generate hyrax:work DataSet`
module Hyrax
  class DataSetPresenter < Hyrax::WorkShowPresenter
    delegate :abstract, :access, :affiliation, :copyright_date, :date_issued, :doi, :extent,
             :funder, :genre, :geographic_subject, :last_date_modified, :orcid, :other_affiliation,
             :project_director, :researcher, :rights_holder, :sponsor, :use, to: :solr_document
  end
end