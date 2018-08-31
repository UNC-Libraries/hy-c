# Generated via
#  `rails generate hyrax:work DataSet`
module Hyrax
  class DataSetPresenter < Hyrax::WorkShowPresenter
    delegate :abstract, :affiliation, :affiliation_label, :copyright_date, :date_issued, :dcmi_type, :deposit_record, :doi, :extent, :funder,
             :geographic_subject, :kind_of_data, :last_modified_date, :project_director, :researcher, :rights_holder,
             :sponsor, to: :solr_document
  end
end