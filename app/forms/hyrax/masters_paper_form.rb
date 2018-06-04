# Generated via
#  `rails generate hyrax:work MastersPaper`
module Hyrax
  class MastersPaperForm < ::SingleValueForm
    class_attribute :single_value_fields
    
    self.model_class = ::MastersPaper
    self.terms += [:abstract, :academic_concentration, :access, :advisor, :date_issued, :degree,
                   :degree_granting_institution, :extent, :genre, :geographic_subject, :graduation_year, :medium, :note,
                   :reviewer, :use, :resource_type]

    self.terms -= [:contributor, :publisher, :identifier, :based_near, :related_url, :source, :description, :date_created]

    self.required_fields = [:title, :creator, :date_issued, :degree_granting_institution]

    self.single_value_fields = [:title, :license, :rights_statement]

    # Add overrides for required properties which are becoming single-valued

    def title
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