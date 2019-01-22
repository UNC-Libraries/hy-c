# Generated via
#  `rails generate hyrax:work DataSet`
module Hyrax
  class DataSetPresenter < Hyrax::WorkShowPresenter
    delegate :abstract, :contributor_display, :creator_display, :date_issued, :dcmi_type, :deposit_record, :doi,
             :extent, :funder, :geographic_subject, :kind_of_data, :last_modified_date, :language_label,
             :license_label, :methodology, :orcid_label, :other_affiliation_label, :project_director_display, :researcher_display,
             :rights_holder, :rights_statement_label, :sponsor, to: :solr_document
  end
end