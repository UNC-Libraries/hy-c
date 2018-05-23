# Generated via
#  `rails generate hyrax:work General`
module Hyrax
  class GeneralForm < ::SingleValueForm

    class_attribute :single_value_fields

    self.model_class = ::General

    self.terms += [:resource_type, :abstract, :academic_concentration, :access, :advisor, :affiliation, :alternate_title,
                   :award, :bibliographic_citation, :conference_name, :copyright_date, :date_captured, :date_issued, :date_other,
                   :degree, :degree_granting_institution, :digital_collection, :discipline, :doi, :edition, :extent, :funder,
                   :geographic_subject, :graduation_year, :isbn, :issn, :journal_issue, :journal_title, :journal_volume,
                   :kind_of_data, :last_modified_date, :medium, :note, :orcid, :other_affiliation, :page_start, :page_end,
                   :peer_review_status, :place_of_publication, :project_director, :researcher, :reviewer, :rights_holder,
                   :series, :sponsor, :table_of_contents, :translator, :url, :use]

    self.required_fields -= [:creator, :keyword, :rights_statement]

    self.terms -= [:based_near]

    self.single_value_fields = [:title]

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
