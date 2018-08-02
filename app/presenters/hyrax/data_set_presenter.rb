# Generated via
#  `rails generate hyrax:work DataSet`
module Hyrax
  class DataSetPresenter < Hyrax::WorkShowPresenter
    delegate :abstract, :affiliation, :copyright_date, :date_issued, :deposit_record, :doi, :extent, :funder, :dcmi_type,
             :geographic_subject, :kind_of_data, :last_modified_date, :project_director, :researcher, :rights_holder,
             :sponsor, to: :solr_document
  end
end