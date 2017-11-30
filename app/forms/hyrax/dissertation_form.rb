# Generated via
#  `rails generate hyrax:work Dissertation`
module Hyrax
  class DissertationForm < ::SingleValueForm
    class_attribute :single_value_fields

    self.model_class = ::Dissertation
    self.terms += [:faculty_advisor_name, :date_published, :author_graduation_date, :author_degree_granted,
                   :author_academic_concentration, :institution, :citation]
    self.terms -= [:contributor, :publisher, :date_created, :identifier, :based_near, :related_url, :source, :license]
    self.single_value_fields = [:title]

    # Add overrides for required properties which are becoming single-valued

    def title
      super.first || ""
    end
  end
end
