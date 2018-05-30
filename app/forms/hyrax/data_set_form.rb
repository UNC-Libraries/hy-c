# Generated via
#  `rails generate hyrax:work DataSet`
module Hyrax
  class DataSetForm < ::SingleValueForm
    class_attribute :single_value_fields

    self.model_class = ::DataSet

    self.terms += [:resource_type, :abstract, :access, :affiliation, :copyright_date, :date_issued, :doi, :extent,
                   :funder, :genre, :geographic_subject, :last_modified_date, :orcid, :other_affiliation,
                   :project_director, :researcher, :rights_holder, :sponsor, :use
    ]

    self.terms -= [:based_near, :publisher]

    self.required_fields -= [:keyword]

    self.single_value_fields = [:title, :date_created]

    # Add overrides for required properties which are becoming single-valued

    def title
      super.first || ""
    end

    def date_created
      super.first || ""
    end
  end
end
