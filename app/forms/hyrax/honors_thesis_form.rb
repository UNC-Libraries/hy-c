# Generated via
#  `rails generate hyrax:work HonorsThesis`
module Hyrax
  class HonorsThesisForm < ::SingleValueForm
    self.model_class = ::HonorsThesis

    class_attribute :single_value_fields

    self.terms += [:abstract, :academic_concentration, :access, :advisor, :affiliation, :alternative_title, :award, :date_issued,
                   :degree, :degree_granting_institution, :doi, :extent, :genre, :geographic_subject, :graduation_year, :note,
                   :use, :resource_type]
    self.terms -= [:based_near, :contributor, :description, :identifier, :publisher, :source]
    self.required_fields = [:title, :abstract, :academic_concentration, :advisor, :creator,
                            :degree, :date_created, :graduation_year]
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
