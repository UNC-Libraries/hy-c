# Generated via
#  `rails generate hyrax:work DataSet`
module Hyrax
  class DataSetPresenter < Hyrax::WorkShowPresenter
    delegate :abstract, :affiliation, :affiliation_label, :date_issued, :dcmi_type, :deposit_record,
             :doi, :extent, :funder, :geographic_subject, :kind_of_data, :last_modified_date, :language_label,
             :license_label, :orcid, :other_affiliation, :project_director, :researcher, :rights_holder,
             :rights_statement_label, :sponsor, to: :solr_document
  end
end