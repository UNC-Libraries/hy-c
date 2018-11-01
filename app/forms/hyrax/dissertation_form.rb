# Generated via
#  `rails generate hyrax:work Dissertation`
module Hyrax
  class DissertationForm < ::SingleValueForm
    class_attribute :single_value_fields

    self.model_class = ::Dissertation
    self.terms += [:abstract, :academic_concentration, :access, :advisor, :affiliation, :affiliation_label,
                   :alternative_title, :date_issued, :dcmi_type, :degree, :degree_granting_institution, :doi,
                   :geographic_subject, :graduation_year, :note, :orcid, :place_of_publication, :resource_type,
                   :reviewer, :use]

    self.terms -= [:based_near, :bibliographic_citation, :date_created, :description, :source, :related_url]
    self.required_fields = [:title, :creator, :degree_granting_institution, :date_issued]
    self.single_value_fields = [:title, :license, :rights_statement]
    
    self.admin_only_terms = [:dcmi_type]
    self.default_term_values = { :dcmi_type => ["http://purl.org/dc/dcmitype/Text"], :degree_granting_institution => ["University of North Carolina at Chapel Hill"] }

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
