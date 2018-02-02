# Generated via
#  `rails generate hyrax:work DataSet`
module Hyrax
  class DataSetForm < ::SingleValueForm
    class_attribute :single_value_fields

    self.model_class = ::DataSet

    self.terms += [:resource_type, :abstract, :access, :affiliation, :copyright_date, :date_issued, :doi, :extent,
                   :funder, :genre, :geographic_subject, :last_date_modified, :orcid, :other_affiliation,
                   :project_director, :researcher, :rights_holder, :sponsor, :use
    ]

    self.terms -= [:based_near, :publisher]

    self.required_fields -= [:keyword]

    self.single_value_fields = [:title]

    # Add overrides for required properties which are becoming single-valued

    def title
      super.first || ""
    end
  end
end
