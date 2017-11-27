# Generated via
#  `rails generate hyrax:work Dissertation`
module Hyrax
  class DissertationForm < Hyrax::Forms::WorkForm
    class_attribute :single_value_fields

    self.model_class = ::Dissertation
    self.terms += [:faculty_advisor_name, :date_published, :author_graduation_date, :author_degree_granted,
                   :author_academic_concentration, :institution, :citation]
    self.terms -= [:contributor, :publisher, :date_created, :identifier, :based_near, :related_url, :source, :license]
    self.single_value_fields = [:title]

    def self.multiple?(field)
      if single_value_fields.include? field.to_sym
        false
      else
        super
      end
    end

    def self.model_attributes(_)
      attrs = super

      single_value_fields.each do |field|
        if attrs[field]
          if attrs[field].blank?
            attrs[field] = []
          else
            attrs[field] = Array(attrs[field])
          end
        end
      end
      
      attrs
    end

    def title
      super.first || ""
    end
  end
end
