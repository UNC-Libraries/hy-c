# frozen_string_literal: true
# Generated via
#  `rails generate hyrax:work Multimed`
module Hyrax
  class MultimedForm < ::SingleValueForm
    class_attribute :single_value_fields

    self.model_class = ::Multimed
    self.terms += [:abstract, :dcmi_type, :admin_note, :date_issued, :digital_collection, :doi, :extent, :medium, :note,
                   :resource_type, :deposit_agreement, :agreement]

    self.terms -= [:contributor, :description, :identifier, :publisher, :related_url, :source, :date_created]

    self.required_fields = [:title, :creator, :abstract, :date_issued, :resource_type]

    self.single_value_fields = [:title, :license]

    self.admin_only_terms = [:dcmi_type, :access, :admin_note, :digital_collection, :doi, :medium]

    self.default_term_values = { rights_statement: 'http://rightsstatements.org/vocab/InC/1.0/',
                                 language: ['http://id.loc.gov/vocabulary/iso639-2/eng'] }

    # Add overrides for required properties which are becoming single-valued

    def title
      super.first || ''
    end

    def license
      super.first || ''
    end

    delegate :creators_attributes=, to: :model

    def creators
      model.creators.build if model.creators.blank?
      model.creators.to_a
    end

    def self.build_permitted_params
      permitted = super
      permitted << { creators_attributes: [:id, :index, :name, :affiliation, :orcid, :other_affiliation, :_destroy] }
      permitted
    end
  end
end
