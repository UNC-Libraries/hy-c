# Generated via
#  `rails generate hyrax:work Article`
module Hyrax
  class ArticleForm < ::SingleValueForm

    class_attribute :single_value_fields

    self.model_class = ::Article
    self.terms += [:resource_type, :abstract, :access, :affiliation, :bibliographic_citation, :copyright_date, :date_captured,
                   :date_issued, :date_other, :doi, :edition, :extent, :funder, :dcmi_type, :geographic_subject, :issn,
                   :journal_issue, :journal_title, :journal_volume, :note, :page_end, :page_start, :peer_review_status,
                   :place_of_publication, :rights_holder, :table_of_contents, :translator, :url, :use]

    self.required_fields = [:title, :creator, :date_issued]

    self.terms -= [:contributor, :based_near, :related_url, :source, :description]
    
    self.single_value_fields = [:title, :date_created, :license, :rights_statement]
    
    self.suppressed_terms = [:dcmi_type]
    self.fixed_term_values = { :dcmi_type => ["http://purl.org/dc/dcmitype/Text"] }

    # Add overrides for required properties which are becoming single-valued

    def title
      super.first || ""
    end

    def date_created
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
