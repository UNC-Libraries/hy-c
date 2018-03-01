# Generated via
#  `rails generate hyrax:work ScholarlyWork`
module Hyrax
  class ScholarlyWorkForm < ::SingleValueForm
    class_attribute :single_value_fields

    self.model_class = ::ScholarlyWork

    self.terms += [:resource_type, :abstract, :advisor, :affiliation, :conference_name, :date_issued, :genre,
                   :geographic_subject, :orcid, :other_affiliation]
    self.terms -= [:contributor, :publisher, :identifier, :based_near, :related_url]
    self.required_fields -= [:keyword, :rights_statement]
    self.single_value_fields = [:title]

    # Add overrides for required properties which are becoming single-valued

    def title
      super.first || ""
    end
  end
end
