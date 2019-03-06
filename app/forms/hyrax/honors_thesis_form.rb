# Generated via
#  `rails generate hyrax:work HonorsThesis`
module Hyrax
  class HonorsThesisForm < ::SingleValueForm
    self.model_class = ::HonorsThesis

    class_attribute :single_value_fields

    self.terms += [:abstract, :access, :advisor, :award, :date_issued, :dcmi_type, :degree, :degree_granting_institution,
                   :doi, :extent, :graduation_year, :honors_concentration, :note, :use, :resource_type]

    self.terms -= [:contributor, :description, :identifier, :publisher, :source]

    self.required_fields = [:title, :creator, :abstract, :advisor, :affiliation, :degree, :date_issued,
                            :graduation_year]

    self.single_value_fields = [:title, :license]
    
    self.admin_only_terms = [:date_created, :dcmi_type, :access, :award,
                             :degree_granting_institution, :doi, :extent, :honors_concentration, :use]

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
