# Generated via
#  `rails generate hyrax:work Multimed`
module Hyrax
  class MultimedForm < ::SingleValueForm
    class_attribute :single_value_fields

    self.model_class = ::Multimed
    self.terms += [:abstract, :extent, :genre, :geographic_subject, :note, :resource_type]

    self.terms -= [:based_near, :contributor, :description, :identifier, :publisher, :related_url, :source]

    self.required_fields -= [:keyword, :rights_statement]

    self.single_value_fields = [:title]

    # Add overrides for required properties which are becoming single-valued

    def title
      super.first || ""
    end

    def date_created
      super.first || ""
    end
  end
end
