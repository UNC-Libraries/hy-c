# Generated via
#  `rails generate hyrax:work Multimedia`
module Hyrax
  class MultimediaForm < ::SingleValueForm
    class_attribute :single_value_fields

    self.model_class = ::Multimedia
    self.terms += [:abstract, :extent, :genre, :geographic_subject, :note, :resource_type]

    self.terms -= [:based_near, :contributor, :description, :publisher, :related_url]

    self.required_fields -= [:keyword, :rights_statement]

    self.single_value_fields = [:title]

    # Add overrides for required properties which are becoming single-valued

    def title
      super.first || ""
    end
  end
end
