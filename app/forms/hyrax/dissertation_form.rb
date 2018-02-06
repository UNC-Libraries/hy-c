# Generated via
#  `rails generate hyrax:work Dissertation`
module Hyrax
  class DissertationForm < ::SingleValueForm
    class_attribute :single_value_fields

    self.model_class = ::Dissertation
    self.terms += [:abstract, :academic_concentration, :affiliation, :access, :advisor, :date_issued, :degree,
                   :degree_granting_institution, :discipline, :doi, :format, :genre, :graduation_year,
                   :note, :place_of_publication, :record_content_source, :resource_type, :reviewer]
    self.terms -= [:based_near, :date_created, :description, :source, :related_url]
    self.required_fields += [:degree_granting_institution]
    self.required_fields -= [:keyword, :rights_statement]
    self.single_value_fields = [:title]

    # Add overrides for required properties which are becoming single-valued

    def title
      super.first || ""
    end
  end
end
