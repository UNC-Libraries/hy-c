# Generated via
#  `rails generate hyrax:work Article`
module Hyrax
  class ArticleForm < Hyrax::Forms::WorkForm
    class_attribute :single_value_fields

    self.model_class = ::Article
    self.terms += [:resource_type, :doi, :date_published, :institution, :citation]
    self.terms -= [:contributor, :date_created, :identifier, :based_near, :related_url, :source]
    self.single_value_fields = [:title, :publisher, :citation]

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

    def publisher
      super.first || ""
    end

    def citation
      super.first || ""
    end

  end
end
