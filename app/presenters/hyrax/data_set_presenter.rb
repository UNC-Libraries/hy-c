# Generated via
#  `rails generate hyrax:work DataSet`
module Hyrax
  class DataSetPresenter < Hyrax::WorkShowPresenter
    delegate :abstract, :affiliation_label, :contributor_display, :copyright_date, :creator_display, :date_issued,
             :dcmi_type, :deposit_record, :doi, :extent, :funder_display, :geographic_subject, :kind_of_data,
             :last_modified_date, :language_label, :license_label, :orcid_label, :other_affiliation_label,
             :person_label, :project_director_display, :orcid_label, :other_affiliation_label, :researcher_display,
             :rights_holder, :rights_statement_label, :sponsor_display, to: :solr_document
  end
end