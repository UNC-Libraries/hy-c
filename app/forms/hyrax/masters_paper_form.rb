# Generated via
#  `rails generate hyrax:work MastersPaper`
module Hyrax
  class MastersPaperForm < ::SingleValueForm
    class_attribute :single_value_fields
    
    self.model_class = ::MastersPaper
    self.terms += [:academic_concentration, :affiliation, :degree, :degree_granting_institution,
                   :graduation_year, :abstract, :advisor, :genre, :access, :extent, :reviewer, :geographic_subject,
                   :note, :medium, :resource_type]
    self.terms -= [:contributor, :publisher, :identifier, :based_near, :related_url, :source, :description]
    self.required_fields -= [:keyword, :rights_statement]
    self.required_fields += [:degree_granting_institution]
    self.single_value_fields = [:title]

    # Add overrides for required properties which are becoming single-valued

    def title
      super.first || ""
    end

    def date_created
      super.first || ""
    end
  end
end
