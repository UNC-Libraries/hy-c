# Generated via
#  `rails generate hyrax:work Work`
module Hyrax
  class WorkForm < Hyrax::Forms::WorkForm
    class_attribute :single_value_fields

    self.model_class = ::Work
    self.terms += [:resource_type]
    self.single_value_fields = [:title, :publisher]

    def self.multiple?(field)
      if single_value_fields.include? field.to_sym
        false
      else
        super
      end
    end

    # cast single value fields back to multivalued so they will actually deposit
    def self.model_attributes(_)
      attrs = super

      single_value_fields.each do |field|
        if attrs[field]
          attrs[field] = Array(attrs[field])
        end
      end

      attrs
    end

    def title
      super.first || ""
    end
  end
end
