# Generated via
#  `rails generate hyrax:work OpenAccess`
module Hyrax
  class OpenAccessForm < ::SingleValueForm
    class_attribute :single_value_fields

    self.model_class = ::OpenAccess
    self.terms += [:academic_department, :orcid, :author_status, :coauthor, :publication, :issue, :publication_date,
                   :publication_version, :link_to_publisher_version, :granting_agency, :additional_funding]
    self.terms -= [:contributor, :publisher, :language, :date_created, :identifier, :based_near, :related_url, :source]
    self.single_value_fields = [:title]

    # Add overrides for required properties which are becoming single-valued

    def title
      super.first || ""
    end
  end
end
