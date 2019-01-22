# Generated via
#  `rails generate hyrax:work HonorsThesis`
module Hyrax
  class HonorsThesisForm < ::SingleValueForm
    self.model_class = ::HonorsThesis

    class_attribute :single_value_fields

    self.terms += [:abstract, :academic_concentration, :access, :advisor, :award, :date_issued, :dcmi_type, :degree,
                   :degree_granting_institution, :doi, :extent, :geographic_subject, :graduation_year, :note, :use,
                   :resource_type]

    self.terms -= [:based_near, :contributor, :description, :identifier, :publisher, :source]

    self.admin_only_terms = [:dcmi_type, :access, :date_created, :degree_granting_institution, :doi, :extent, :rights_holder, :rights_statement]

    self.default_term_values = { :dcmi_type => ["http://purl.org/dc/dcmitype/Text"], :rights_statement => "http://rightsstatements.org/vocab/InC/1.0/",
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
      permitted << { advisors_attributes: [:id, :name, :affiliation, :orcid, :other_affiliation, :_destroy] }
      permitted << { creators_attributes: [:id, :name, :affiliation, :orcid, :other_affiliation, :_destroy] }
      permitted
    end
  end
end
