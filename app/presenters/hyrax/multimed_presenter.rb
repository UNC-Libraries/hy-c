# frozen_string_literal: true
# Generated via
#  `rails generate hyrax:work Multimed`
module Hyrax
  class MultimedPresenter < Hyrax::WorkShowPresenter
    delegate :abstract, :admin_note, :creator_display, :date_issued, :dcmi_type, :deposit_record, :digital_collection, :doi, :extent,
             :language_label, :license_label, :medium, :note, :resource_type, :rights_statement_label,
             to: :solr_document
  end
end
