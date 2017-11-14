# Generated via
#  `rails generate hyrax:work OpenAccess`
module Hyrax
  class OpenAccessForm < Hyrax::Forms::WorkForm
    class_attribute :single_value_fields

    self.model_class = ::OpenAccess
    self.terms += [:academic_department, :orcid, :author_status, :coauthor, :publication, :issue, :publication_date,
                   :publication_version, :link_to_publisher_version, :granting_agency, :additional_funding]
    self.terms -= [:contributor, :publisher, :language, :date_created, :identifier, :based_near, :related_url, :source]
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
