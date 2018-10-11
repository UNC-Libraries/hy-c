# Generated via
#  `rails generate hyrax:work General`
module Hyrax
  class GeneralForm < ::SingleValueForm

    class_attribute :single_value_fields

    self.model_class = ::General

    self.terms += [:resource_type, :bibliographic_citation, :abstract, :academic_concentration, :access, :advisor,
                   :affiliation, :affiliation_label, :alternative_title, :arranger, :award, :composer, :conference_name,
                   :copyright_date, :date_captured, :date_issued, :date_other, :dcmi_type, :degree,
                   :degree_granting_institution, :deposit_record, :doi, :edition, :extent, :funder, :geographic_subject,
                   :graduation_year, :isbn, :issn, :journal_issue, :journal_title, :journal_volume, :kind_of_data,
                   :last_modified_date, :medium, :note, :orcid, :other_affiliation, :page_start, :page_end,
                   :peer_review_status, :place_of_publication, :project_director, :publisher_version, :researcher,
                   :reviewer, :rights_holder, :series, :sponsor, :table_of_contents, :translator, :url, :use]

    self.required_fields = [:title]

    self.terms -= [:based_near, :source]

    self.single_value_fields = [:title, :license, :rights_statement]
    
    self.admin_only_terms = [:dcmi_type]

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
   
    # In the view we have "fields_for :advisor".
    # This method is needed to make fields_for behave as an
    # association and populate the form with the correct
    # committee member data.
    delegate :advisor_attributes=, to: :model

    # We need to call ".to_a" on advisor to force it
    # to resolve.  Otherwise in the form, the fields don't
    # display the advisor's name and affiliation.
    # Instead they display something like:
    # "#<ActiveTriples::Relation:0x007fb564969c88>"
    def advisor
      model.advisor.build if model.advisor.blank?
      model.advisor.to_a
    end

    def self.build_permitted_params
      permitted = super
      permitted << { advisor_attributes: [:id, { name: [] }, { affiliation: [] }, { netid: [] }, :_destroy] }
      permitted
    end
  end
end
