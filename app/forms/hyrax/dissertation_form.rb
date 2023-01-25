# frozen_string_literal: true
# Generated via
#  `rails generate hyrax:work Dissertation`
module Hyrax
  class DissertationForm < ::SingleValueForm
    class_attribute :single_value_fields

    self.model_class = ::Dissertation
    self.terms += [:access, :admin_note, :advisor, :reviewer, :date_issued,
                   :dcmi_type, :degree, :degree_granting_institution, :doi, :graduation_year, :note,
                   :place_of_publication, :resource_type, :use, :deposit_agreement, :agreement]

    self.terms -= [:bibliographic_citation, :date_created, :description, :source, :related_url]
    self.required_fields = [:title, :creator, :date_issued]
    self.single_value_fields = [:title, :license]

    self.admin_only_terms = [:dcmi_type, :admin_note, :degree_granting_institution, :doi]
    self.default_term_values = { dcmi_type: ['http://purl.org/dc/dcmitype/Text'],
                                 language: ['http://id.loc.gov/vocabulary/iso639-2/eng'] }

    # Add overrides for required properties which are becoming single-valued

    def title
      super.first || ''
    end

    def license
      super.first || ''
    end

    delegate :advisors_attributes=, to: :model
    delegate :contributors_attributes=, to: :model
    delegate :creators_attributes=, to: :model
    delegate :reviewers_attributes=, to: :model

    def advisors
      model.advisors.build if model.advisors.blank?
      model.advisors.to_a
    end

    def contributors
      model.contributors.build if model.contributors.blank?
      model.contributors.to_a
    end

    def creators
      model.creators.build if model.creators.blank?
      model.creators.to_a
    end

    def reviewers
      model.reviewers.build if model.reviewers.blank?
      model.reviewers.to_a
    end

    def self.build_permitted_params
      permitted = super
      permitted << { advisors_attributes: [:id, :index, :name, :affiliation, :orcid, :other_affiliation, :_destroy] }
      permitted << { contributors_attributes: [:id, :index, :name, :affiliation, :orcid, :other_affiliation, :_destroy] }
      permitted << { creators_attributes: [:id, :index, :name, :affiliation, :orcid, :other_affiliation, :_destroy] }
      permitted << { reviewers_attributes: [:id, :index, :name, :affiliation, :orcid, :other_affiliation, :_destroy] }
      permitted
    end
  end
end
