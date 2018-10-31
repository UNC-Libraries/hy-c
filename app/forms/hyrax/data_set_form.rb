# Generated via
#  `rails generate hyrax:work DataSet`
module Hyrax
  class DataSetForm < ::SingleValueForm
    class_attribute :single_value_fields

    self.model_class = ::DataSet

    self.terms += [:resource_type, :abstract, :affiliation, :affiliation_label, :date_issued,
                   :dcmi_type, :doi, :extent, :funder, :geographic_subject, :kind_of_data, :last_modified_date, :orcid,
                   :other_affiliation, :project_director, :researcher, :rights_holder, :sponsor
    ]

    self.terms -= [:based_near, :bibliographic_citation, :publisher, :source, :identifier]

    self.required_fields = [:title, :creator, :date_issued, :abstract, :kind_of_data, :resource_type]

    self.single_value_fields = [:title, :license]
    
    self.admin_only_terms = [:dcmi_type]
    self.default_term_values = { :dcmi_type => ["http://purl.org/dc/dcmitype/Dataset"] }

    # Add overrides for required properties which are becoming single-valued

    def title
      super.first || ""
    end

    def license
      super.first || ""
    end
  end
end
