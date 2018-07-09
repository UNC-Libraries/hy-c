# Generated via
#  `rails generate hyrax:work General`
module Hyrax
  class GeneralForm < ::SingleValueForm

    class_attribute :single_value_fields

    self.model_class = ::General

    self.terms += [:resource_type, :bibliographic_citation, :abstract, :academic_concentration, :access, :advisor,
                   :alternative_title, :arranger, :award, :composer, :conference_name, :copyright_date, :date_captured,
                   :date_issued, :date_other, :degree, :degree_granting_institution, :deposit_record, :digital_collection, :discipline,
                   :doi, :edition, :extent, :funder, :genre, :geographic_subject, :graduation_year, :isbn, :issn,
                   :journal_issue, :journal_title, :journal_volume, :kind_of_data, :last_modified_date, :medium, :note,
                   :page_start, :page_end, :peer_review_status, :place_of_publication, :project_director, :researcher,
                   :reviewer, :rights_holder, :series, :sponsor, :table_of_contents, :translator, :url, :use]

    self.required_fields = [:title, :creator]

    self.terms -= [:based_near, :source]

    self.single_value_fields = [:title, :license, :rights_statement]

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
