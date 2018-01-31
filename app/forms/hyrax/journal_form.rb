# Generated via
#  `rails generate hyrax:work Journal`
module Hyrax
  class JournalForm < ::SingleValueForm
    class_attribute :single_value_fields
    
    self.model_class = ::Journal

    self.terms += [:resource_type, :abstract, :alternate_title, :date_issued, :extent, :genre,
                   :geographic_subject, :issn, :note, :place_of_publication, :table_of_contents
    ]
    self.terms -= [:description, :based_near, :related_url]

    self.required_fields -= [:keyword]

    self.single_value_fields = [:title]

    # Add overrides for required properties which are becoming single-valued

    def title
      super.first || ""
    end
  end
end
