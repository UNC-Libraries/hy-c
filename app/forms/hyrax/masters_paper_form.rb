# Generated via
#  `rails generate hyrax:work MastersPaper`
module Hyrax
  class MastersPaperForm < ::SingleValueForm
    class_attribute :single_value_fields
    
    self.model_class = ::MastersPaper
    self.terms += [:faculty_advisor_name, :date_published, :author_graduation_date, :author_degree_granted]
    self.terms -= [:contributor, :publisher, :date_created, :language, :identifier, :based_near, :related_url, :source]
    self.single_value_fields = [:title]

    # Add overrides for required properties which are becoming single-valued

    def title
      super.first || ""
    end
  end
end
