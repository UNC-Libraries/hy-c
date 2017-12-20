# Generated via
#  `rails generate hyrax:work HonorsThesis`
module Hyrax
  class HonorsThesisForm < ::SingleValueForm
    self.model_class = ::HonorsThesis

    class_attribute :single_value_fields

    self.terms += [:abstract, :academic_concentration, :academic_department, :advisor, :degree,
                   :degree_granting_institution, :genre, :graduation_year, :honors_level, :note, :resource_type]
    self.terms -= [:based_near, :contributor, :date_created, :description, :identifier, :publisher, :source]
    self.required_fields += [:abstract, :academic_department, :advisor, :degree_granting_institution, :resource_type]
    self.required_fields -= [:keyword]
    self.single_value_fields = [:title]

    # Add overrides for required properties which are becoming single-valued

    def title
      super.first || ""
    end
  end
end
