# Generated via
#  `rails generate hyrax:work DataSet`
module Hyrax
  class DataSetForm < ::SingleValueForm
    class_attribute :single_value_fields

    self.model_class = ::DataSet

    self.terms += [:resource_type, :abstract, :academic_department ,:access, :copyright_date, :date_issued, :doi, :extent,
                   :funder, :genre, :geographic_subject, :last_date_modified, :orcid, :other_affiliation,
                   :project_director, :researcher, :rights_holder, :sponsor, :use
    ]

    self.terms -= [:based_near]

    self.single_value_fields = [:access, :copyright_date, :date_created, :date_issued,
                                :doi, :last_date_modified, :title
    ]

    # Add overrides for required properties which are becoming single-valued

    def access
      super.first || ""
    end

    def copyright_date
      super.first || ""
    end

    def date_created
      super.first || ""
    end

    def date_issued
      super.first || ""
    end

    def doi
      super.first || ""
    end

    def last_date_modified
      super.first || ""
    end

    def title
      super.first || ""
    end
  end
end
