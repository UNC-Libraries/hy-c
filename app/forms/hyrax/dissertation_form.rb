# Generated via
#  `rails generate hyrax:work Dissertation`
module Hyrax
  class DissertationForm < ::SingleValueForm
    class_attribute :single_value_fields

    self.model_class = ::Dissertation
    self.terms += [:abstract, :academic_concentration, :access, :advisor, :alternative_title, :date_issued, :degree,
                   :degree_granting_institution, :discipline, :doi, :genre, :geographic_subject, :graduation_year,
                   :note, :place_of_publication, :resource_type, :reviewer, :use]
    self.terms -= [:based_near, :date_created, :description, :source, :related_url]
    self.required_fields = [:title, :creator, :degree_granting_institution, :date_issued]
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
