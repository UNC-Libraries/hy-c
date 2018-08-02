# Generated via
#  `rails generate hyrax:work ScholarlyWork`
module Hyrax
  class ScholarlyWorkForm < ::SingleValueForm
    class_attribute :single_value_fields

    self.model_class = ::ScholarlyWork

    self.terms += [:resource_type, :abstract, :advisor, :conference_name, :date_issued, :doi, :dcmi_type, :geographic_subject]

    self.terms -= [:contributor, :publisher, :identifier, :based_near, :related_url, :source]

    self.required_fields = [:title, :creator, :date_created]

    self.single_value_fields = [:title, :date_created, :license, :rights_statement]

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
