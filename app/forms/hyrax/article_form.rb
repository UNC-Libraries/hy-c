# Generated via
#  `rails generate hyrax:work Article`
module Hyrax
  class ArticleForm < ::SingleValueForm

    class_attribute :single_value_fields

    self.model_class = ::Article
    self.terms += [:resource_type, :doi, :date_published, :degree_granting_institution, :citation]
    self.terms -= [:contributor, :date_created, :identifier, :based_near, :related_url, :source]
    self.single_value_fields = [:title, :publisher]

    # Add overrides for required properties which are becoming single-valued

    def title
      super.first || ""
    end

    def publisher
      super.first || ""
    end
  end
end
