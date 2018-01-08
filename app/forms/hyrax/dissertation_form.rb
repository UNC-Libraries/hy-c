# Generated via
#  `rails generate hyrax:work Dissertation`
module Hyrax
  class DissertationForm < ::SingleValueForm
    class_attribute :single_value_fields

    self.model_class = ::Dissertation
    self.terms += [:abstract, :academic_concentration, :academic_department, :access, :advisor, :date_issued, :degree,
                   :degree_granting_institution, :discipline, :doi, :format, :genre, :graduation_year,
                   :note, :place_of_publication, :record_content_source, :resource_type, :reviewer]
    self.terms -= [:based_near, :date_created, :description, :source, :related_url]
    self.required_fields += [:academic_department, :degree_granting_institution, :abstract, :advisor, :resource_type,
                             :license]
    self.required_fields -= [:keyword]
    self.single_value_fields = [:title]

    # Add overrides for required properties which are becoming single-valued

    def title
      super.first || ""
    end
  end
end
