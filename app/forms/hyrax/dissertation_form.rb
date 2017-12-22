# Generated via
#  `rails generate hyrax:work Dissertation`
module Hyrax
  class DissertationForm < ::SingleValueForm
    class_attribute :single_value_fields

    self.model_class = ::Dissertation
    self.terms += [:advisor, :date_published, :graduation_year, :degree, :academic_concentration,
                   :degree_granting_institution, :citation]
    self.terms -= [:contributor, :publisher, :date_created, :identifier, :based_near, :related_url, :source, :license]
    self.single_value_fields = [:title]

    # Add overrides for required properties which are becoming single-valued

    def title
      super.first || ""
    end
  end
end
