# Generated via
#  `rails generate hyrax:work Article`
module Hyrax
  class ArticleForm < ::SingleValueForm

    class_attribute :single_value_fields

    self.model_class = ::Article
    self.terms += [:resource_type, :abstract, :access, :affiliation, :affiliation_label, :bibliographic_citation,
                   :copyright_date, :date_captured, :date_issued, :date_other, :dcmi_type, :doi, :edition, :extent,
                   :funder, :geographic_subject, :issn, :journal_issue, :journal_title, :journal_volume, :note, :orcid,
                   :other_affiliation, :page_end, :page_start, :peer_review_status, :place_of_publication,
                   :rights_holder, :table_of_contents, :translator, :url, :use]

    self.required_fields = [:title, :creator, :abstract, :date_issued]

    self.terms -= [:contributor, :based_near, :source, :description]
    
    self.single_value_fields = [:title, :license, :rights_statement]
    
    self.admin_only_terms = [:dcmi_type, :date_created, :access, :citation, :identifier, :subject, :use]
    self.default_term_values = { :dcmi_type => ["http://purl.org/dc/dcmitype/Text"], :language => ["http://id.loc.gov/vocabulary/iso639-2/eng"] }

    # Add overrides for required properties which are becoming single-valued

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
