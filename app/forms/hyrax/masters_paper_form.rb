# Generated via
#  `rails generate hyrax:work MastersPaper`
module Hyrax
  class MastersPaperForm < ::SingleValueForm
    class_attribute :single_value_fields
    
    self.model_class = ::MastersPaper
    self.terms += [:abstract, :academic_concentration, :access, :advisor, :affiliation, :date_issued, :dcmi_type,
                   :degree, :degree_granting_institution, :doi, :extent, :geographic_subject, :graduation_year, :note,
                   :orcid, :reviewer, :use, :resource_type]

    self.terms -= [:contributor, :publisher, :identifier, :based_near, :related_url, :source, :description, :date_created]

    self.required_fields = [:title, :creator, :abstract, :advisor, :date_issued, :degree, :degree_granting_institution,
                            :graduation_year, :resource_type]

    self.single_value_fields = [:title, :license, :rights_statement]
    
    self.admin_only_terms = [:dcmi_type]
    self.default_term_values = { :dcmi_type => ["http://purl.org/dc/dcmitype/Text"] }

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