# Generated via
#  `rails generate hyrax:work HonorsThesis`
module Hyrax
  class HonorsThesisForm < ::SingleValueForm
    self.model_class = ::HonorsThesis

    class_attribute :single_value_fields

    self.terms += [:abstract, :academic_concentration, :access, :advisor, :affiliation, :alternative_title, :award,
                   :date_issued, :dcmi_type, :degree, :degree_granting_institution, :doi, :extent, :geographic_subject,
                   :graduation_year, :note, :orcid, :url, :use, :resource_type]

    self.terms -= [:based_near, :contributor, :description, :identifier, :publisher, :source]
    self.required_fields = [:title, :abstract, :advisor, :affiliation, :creator, :date_created, :degree,
                            :degree_granting_institution, :graduation_year]
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
