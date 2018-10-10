# Generated via
#  `rails generate hyrax:work ArtWork`
module Hyrax
  # Generated form for ArtWork
  class ArtWorkForm < ::SingleValueForm

    class_attribute :single_value_fields

    self.model_class = ::ArtWork
    self.terms += [:resource_type, :doi, :extent, :medium]
    self.terms -= [:contributor, :creator, :keyword, :publisher, :subject, :language, :identifier, :based_near,
                   :related_url, :source, :language_label]
    self.required_fields = [:title, :date_created, :description, :extent, :medium, :resource_type]

    # Add overrides for required properties which are becoming single-valued
    self.single_value_fields = [:title, :license, :rights_statement]

    def title
      super.first || ""
    end

    def license
      super.first || ""
    end

    def rights_statement
      super.first || ""
    end
  end
end
