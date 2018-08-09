# Generated via
#  `rails generate hyrax:work Journal`
module Hyrax
  class JournalForm < ::SingleValueForm
    class_attribute :single_value_fields
    
    self.model_class = ::Journal

    self.terms += [:abstract, :alternative_title, :date_issued, :dcmi_type, :doi, :extent, :geographic_subject, :issn, :note,
                  :place_of_publication, :table_of_contents, :resource_type]

    self.terms -= [:description, :based_near, :related_url, :identifier, :contributor, :source, :date_created]

    self.required_fields = [:title, :date_issued]

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
