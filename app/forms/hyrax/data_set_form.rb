# Generated via
#  `rails generate hyrax:work DataSet`
module Hyrax
  class DataSetForm < ::SingleValueForm
    class_attribute :single_value_fields

    self.model_class = ::DataSet

    self.terms += [:resource_type, :abstract, :affiliation, :copyright_date, :date_issued, :doi, :extent,
                   :funder, :genre, :geographic_subject, :kind_of_data, :last_modified_date,
                   :project_director, :researcher, :rights_holder, :sponsor
    ]

    self.terms -= [:based_near, :description, :kind_of_data, :publisher, :source, :identifier, :rights_statement]

    self.required_fields = [:title, :creator, :date_issued]

    self.single_value_fields = [:title, :license]

    # Add overrides for required properties which are becoming single-valued

    def title
      super.first || ""
    end

    def license
      super.first || ""
    end
  end
end
