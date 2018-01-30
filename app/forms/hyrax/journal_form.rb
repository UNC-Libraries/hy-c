# Generated via
#  `rails generate hyrax:work Journal`
module Hyrax
  class JournalForm < Hyrax::Forms::WorkForm
    class_attribute :single_value_fields
    
    self.model_class = ::Journal

    self.terms += [:resource_type, :abstract, :alternate_title, :extent, :genre,
                   :geographic_subject, :issn, :note, :place_of_publication, :table_of_contents
    ]
    self.terms -= [:description, :based_near, :related_url]
    self.single_value_fields = [:title]
  end
end
