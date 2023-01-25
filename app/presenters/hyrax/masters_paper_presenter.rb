# frozen_string_literal: true
# Generated via
#  `rails generate hyrax:work MastersPaper`
module Hyrax
  class MastersPaperPresenter < Hyrax::WorkShowPresenter
    delegate :abstract, :academic_concentration, :access, :admin_note, :advisor_display, :creator_display, :date_issued, :dcmi_type,
             :degree, :degree_granting_institution, :deposit_record, :doi, :extent,
             :graduation_year, :language_label, :license_label, :note, :reviewer_display, :rights_statement_label, :use,
             to: :solr_document

    # See: WorkShowPresenter.scholarly?
    def scholarly?
      true
    end
  end
end
