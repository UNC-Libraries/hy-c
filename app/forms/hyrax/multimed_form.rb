# Generated via
#  `rails generate hyrax:work Multimed`
module Hyrax
  class MultimedForm < ::SingleValueForm
    class_attribute :single_value_fields

    self.model_class = ::Multimed
    self.terms += [:abstract, :dcmi_type, :date_issued, :doi, :extent, :geographic_subject, :medium, :note,
                   :resource_type]

    self.terms -= [:based_near, :contributor, :description, :identifier, :publisher, :related_url, :source]

    self.required_fields = [:title, :creator, :abstract, :date_issued, :resource_type]

    self.single_value_fields = [:title, :license]
    
    self.admin_only_terms = [:dcmi_type, :access, :date_created, :doi, :medium]

    self.default_term_values = { :rights_statement => "http://rightsstatements.org/vocab/InC/1.0/", :language => ["http://id.loc.gov/vocabulary/iso639-2/eng"] }

    # Add overrides for required properties which are becoming single-valued

    def title
      super.first || ""
    end

    def license
      super.first || ""
    end


    delegate :creators_attributes=, to: :model

    def creators
      model.creators.build if model.creators.blank?
      model.creators.to_a
    end

    def self.build_permitted_params
      permitted = super
      permitted << { creators_attributes: [:id, :name, :affiliation, :orcid, :other_affiliation, :_destroy] }
      permitted
    end
  end
end
