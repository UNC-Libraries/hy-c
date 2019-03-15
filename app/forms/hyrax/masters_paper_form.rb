# Generated via
#  `rails generate hyrax:work MastersPaper`
module Hyrax
  class MastersPaperForm < ::SingleValueForm
    class_attribute :single_value_fields
    
    self.model_class = ::MastersPaper
    self.terms += [:abstract, :academic_concentration, :access, :advisor, :reviewer, :date_issued, :dcmi_type, :degree,
                   :degree_granting_institution, :doi, :extent, :graduation_year, :note,
                   :use, :resource_type, :deposit_agreement, :agreement]

    self.terms -= [:contributor, :publisher, :identifier, :related_url, :source, :description, :date_created]

    self.required_fields = [:title, :creator, :abstract, :advisor, :date_issued, :degree,
                            :graduation_year, :resource_type]

    self.single_value_fields = [:title, :license]
    
    self.admin_only_terms = [:dcmi_type, :access, :degree_granting_institution, :doi, :extent, :use]
    self.default_term_values = { :dcmi_type => ["http://purl.org/dc/dcmitype/Text"],
                                 :rights_statement => "http://rightsstatements.org/vocab/InC/1.0/",
                                 :language => ["http://id.loc.gov/vocabulary/iso639-2/eng"] }

    # Add overrides for required properties which are becoming single-valued

    def title
      super.first || ""
    end

    def license
      super.first || ""
    end


    delegate :advisors_attributes=, to: :model
    delegate :creators_attributes=, to: :model
    delegate :reviewers_attributes=, to: :model

    def advisors
      model.advisors.build if model.advisors.blank?
      model.advisors.to_a
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
      permitted << { advisors_attributes: [:id, :name, :affiliation, :orcid, :other_affiliation, :_destroy] }
      permitted << { creators_attributes: [:id, :name, :affiliation, :orcid, :other_affiliation, :_destroy] }
      permitted << { reviewers_attributes: [:id, :name, :affiliation, :orcid, :other_affiliation, :_destroy] }
      permitted
    end
  end
end