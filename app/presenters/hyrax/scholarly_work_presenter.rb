# frozen_string_literal: true
# Generated via
#  `rails generate hyrax:work ScholarlyWork`
module Hyrax
  class ScholarlyWorkPresenter < Hyrax::WorkShowPresenter
    delegate :abstract, :admin_note, :advisor_display, :conference_name, :creator_display, :date_issued, :dcmi_type, :deposit_record,
             :digital_collection, :doi, :language_label, :license_label, :note, :rights_statement_label, to: :solr_document

    # See: WorkShowPresenter.scholarly?
    def scholarly?
      true
    end
  end
end
