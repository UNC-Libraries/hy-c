# frozen_string_literal: true
# Generated via
#  `rails generate hyrax:work DataSet`
module Hyrax
  class DataSetPresenter < Hyrax::WorkShowPresenter
    delegate :abstract, :admin_note, :contributor_display, :copyright_date, :creator_display, :date_issued, :dcmi_type, :deposit_record, :doi,
             :extent, :funder, :kind_of_data, :last_modified_date, :language_label,
             :license_label, :methodology, :note, :orcid_label, :other_affiliation_label, :project_director_display, :researcher_display,
             :rights_holder, :rights_statement_label, :sponsor, to: :solr_document

    # See: WorkShowPresenter.scholarly?
    def scholarly?
      true
    end
  end
end
