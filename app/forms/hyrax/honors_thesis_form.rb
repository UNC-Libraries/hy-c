# frozen_string_literal: true
# Generated via
#  `rails generate hyrax:work HonorsThesis`
module Hyrax
  class HonorsThesisForm < ::SingleValueForm
    self.model_class = ::HonorsThesis

    class_attribute :single_value_fields

    self.terms += [:academic_concentration, :admin_note, :advisor, :award, :date_issued, :dcmi_type, :degree,
                   :degree_granting_institution, :doi, :extent, :graduation_year, :note, :resource_type,
                   :deposit_agreement, :agreement]

    self.terms -= [:contributor, :description, :identifier, :publisher, :source, :date_created]

    self.required_fields = [:title, :creator, :abstract, :advisor, :degree, :date_issued,
                            :graduation_year]

    self.single_value_fields = [:title, :license]

    self.admin_only_terms = [:dcmi_type, :academic_concentration, :admin_note, :award,
                             :degree_granting_institution, :doi, :extent]

    self.default_term_values = { dcmi_type: ['http://purl.org/dc/dcmitype/Text'],
                                 rights_statement: 'http://rightsstatements.org/vocab/InC/1.0/',
                                 language: ['http://id.loc.gov/vocabulary/iso639-2/eng'] }

    # Add overrides for required properties which are becoming single-valued

    def title
      super.first || ''
    end

    def license
      super.first || ''
    end

    delegate :advisors_attributes=, to: :model
    delegate :creators_attributes=, to: :model

    def advisors
      model.advisors.build if model.advisors.blank?
      model.advisors.to_a
    end

    def creators
      model.creators.build if model.creators.blank?
      model.creators.to_a
    end

    def self.build_permitted_params
      permitted = super
      permitted << { advisors_attributes: [:id, :index, :name, :affiliation, :orcid, :other_affiliation, :_destroy] }
      permitted << { creators_attributes: [:id, :index, :name, :affiliation, :orcid, :other_affiliation, :_destroy] }
      permitted
    end
  end
end
