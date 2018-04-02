# Generated via
#  `rails generate hyrax:work Article`
module Hyrax
  class ArticleForm < ::SingleValueForm

    class_attribute :single_value_fields

    self.model_class = ::Article
    self.terms += [:resource_type, :abstract, :access, :affiliation, :copyright_date, :date_captured,
                   :date_issued, :date_other, :doi, :edition, :extent, :funder, :genre,
                   :geographic_subject, :issn, :journal_issue, :journal_title, :journal_volume, :note, :orcid,
                   :other_affiliation, :page_end, :page_start, :peer_review_status, :place_of_publication, :rights_holder,
                   :table_of_contents, :translator, :url, :use]

    self.required_fields -= [:keyword]

    self.terms -= [:contributor, :based_near, :related_url, :source]
    
    self.single_value_fields = [:title, :publisher]

    # Add overrides for required properties which are becoming single-valued

    def title
      super.first || ""
    end

    def publisher
      super.first || ""
    end

    def date_created
      super.first || ""
    end
  end
end
