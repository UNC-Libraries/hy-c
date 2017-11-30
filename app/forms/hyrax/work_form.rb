# Generated via
#  `rails generate hyrax:work Work`
module Hyrax
  class WorkForm < ::SingleValueForm
    class_attribute :single_value_fields

    self.model_class = ::Work
    self.terms += [:resource_type]
    self.single_value_fields = [:title, :publisher]

    # Add overrides for required properties which are becoming single-valued

    def title
      super.first || ""
    end
  end
end
