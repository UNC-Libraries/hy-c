# Generated via
#  `rails generate hyrax:work Multimed`
module Hyrax
  class MultimedForm < ::SingleValueForm
    class_attribute :single_value_fields

    self.model_class = ::Multimed
    self.terms += [:abstract, :dcmi_type, :date_issued, :doi, :extent, :geographic_subject, :medium, :note, :orcid, :resource_type]

    self.terms -= [:based_near, :contributor, :description, :identifier, :publisher, :related_url, :source]

    self.required_fields = [:title, :creator, :abstract, :date_issued, :resource_type]

    self.single_value_fields = [:title, :license]
    
    self.admin_only_terms = [:dcmi_type, :access, :date_created, :doi]

    self.default_term_values = { :rights_statement => "http://rightsstatements.org/vocab/InC/1.0/" }

    # Add overrides for required properties which are becoming single-valued

    def title
      super.first || ""
    end

    def license
      super.first || ""
    end
  end
end
