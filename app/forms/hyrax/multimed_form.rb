# Generated via
#  `rails generate hyrax:work Multimed`
module Hyrax
  class MultimedForm < ::SingleValueForm
    class_attribute :single_value_fields

    self.model_class = ::Multimed
    self.terms += [:abstract, :doi, :extent, :dcmi_type, :geographic_subject, :note, :resource_type]

    self.terms -= [:based_near, :contributor, :description, :identifier, :publisher, :related_url, :source]

    self.required_fields = [:title, :creator]

    self.single_value_fields = [:title, :date_created, :license, :rights_statement]
    
    self.suppressed_terms = [:dcmi_type]
    self.fixed_term_values = { :dcmi_type => [] }

    # Add overrides for required properties which are becoming single-valued

    def title
      super.first || ""
    end

    def date_created
      super.first || ""
    end

    def license
      super.first || ""
    end

    def rights_statement
      super.first || ""
    end
  end
end
