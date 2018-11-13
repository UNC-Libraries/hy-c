# Generated via
#  `rails generate hyrax:work ScholarlyWork`
module Hyrax
  class ScholarlyWorkForm < ::SingleValueForm
    class_attribute :single_value_fields

    self.model_class = ::ScholarlyWork

    self.terms += [:resource_type, :abstract, :advisor, :affiliation, :affiliation_label, :conference_name,
                   :date_issued, :dcmi_type, :doi, :geographic_subject, :orcid, :other_affiliation]

    self.terms -= [:contributor, :publisher, :identifier, :based_near, :related_url, :source]

    self.required_fields = [:title, :creator, :abstract, :date_issued]

    self.single_value_fields = [:title, :license]
    
    self.admin_only_terms = [:dcmi_type, :date_created, :access, :use]

    self.default_term_values = { :rights_statement => "http://rightsstatements.org/vocab/InC/1.0/" }

    # Add overrides for required properties which are becoming single-valued

    def title
      super.first || ""
    end

    def license
      super.first || ""
    end
  end
end
