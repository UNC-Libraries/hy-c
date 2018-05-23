# Generated via
#  `rails generate hyrax:work General`
module Hyrax
  class GeneralForm < ::SingleValueForm

    class_attribute :single_value_fields

    self.model_class = ::General

    self.terms += [:resource_type, :alternative_title, :advisor, :funder, :project_director, :researcher, :sponsor,
                   :translator, :reviewer, :degree_granting_institution, :conference_name, :orcid, :affiliation,
                   :other_affiliation, :date_issued, :copyright_date, :last_date_modified, :date_other, :date_captured,
                   :graduation_year, :abstract, :note, :extent, :table_of_contents, :citation, :edition,
                   :peer_review_status, :degree, :academic_concentration, :discipline, :award, :medium, :kind_of_data,
                   :series, :geographic_subject, :use, :rights_holder, :access, :doi, :issn, :isbn,
                   :place_of_publication, :journal_title, :journal_volume, :journal_issue, :start_page, :end_page, :url,
                   :digital_collection]

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
