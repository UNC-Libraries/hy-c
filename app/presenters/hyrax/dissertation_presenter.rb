# frozen_string_literal: true
# Generated via
#  `rails generate hyrax:work Dissertation`
module Hyrax
  class DissertationPresenter < Hyrax::WorkShowPresenter
    delegate :abstract, :admin_note, :advisor_display, :alternative_title, :contributor_display,
             :creator_display, :date_issued, :dcmi_type, :degree, :degree_granting_institution, :deposit_record, :doi,
             :graduation_year, :language_label, :license_label, :note, :place_of_publication,
             :resource_type, :reviewer_display, :rights_statement_label, to: :solr_document

    # See: WorkShowPresenter.scholarly?
    def scholarly?
      true
    end
  end
end
