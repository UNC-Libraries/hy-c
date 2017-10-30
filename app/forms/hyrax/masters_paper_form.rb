# Generated via
#  `rails generate hyrax:work MastersPaper`
module Hyrax
  class MastersPaperForm < Hyrax::Forms::WorkForm
    class_attribute :single_value_fields
    
    self.model_class = ::MastersPaper
    self.terms += [:faculty_advisor_name, :date_published, :author_graduation_date, :author_degree_granted]
    self.terms -= [:contributor, :publisher, :date_created, :language, :identifier, :based_near, :related_url, :source]
    self.single_value_fields = [:title]

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
