# frozen_string_literal: true
# Generated via
#  `rails generate hyrax:work Artwork`
module Hyrax
  class ArtworkPresenter < Hyrax::WorkShowPresenter
    delegate :abstract, :admin_note, :creator_display, :date_issued, :dcmi_type, :note, :doi, :extent, :medium,
             :license_label, :rights_statement_label, to: :solr_document
  end
end
