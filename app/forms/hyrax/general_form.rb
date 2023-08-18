# frozen_string_literal: true
# Generated via
#  `rails generate hyrax:work General`
module Hyrax
  class GeneralForm < ::SingleValueForm

    class_attribute :single_value_fields

    self.model_class = ::General

    self.terms += [:resource_type, :admin_note, :bibliographic_citation, :academic_concentration, :advisor,
                   :arranger, :composer, :project_director, :researcher, :reviewer, :translator,
                   :award, :conference_name, :copyright_date, :date_captured, :date_issued,
                   :date_other, :dcmi_type, :degree, :degree_granting_institution, :digital_collection, :doi, :edition, :extent, :funder,
                   :graduation_year, :isbn, :issn, :journal_issue, :journal_title, :journal_volume,
                   :kind_of_data, :last_modified_date, :medium, :methodology, :note, :page_start, :page_end, :peer_review_status,
                   :place_of_publication, :rights_holder, :series, :sponsor, :table_of_contents, :deposit_agreement, :agreement]

    self.required_fields = [:title, :dcmi_type]

    self.terms -= [:date_created, :source]

    self.single_value_fields = [:title, :license]

    self.admin_only_terms = [:dcmi_type, :admin_note, :degree_granting_institution, :digital_collection, :doi, :access_right, :rights_notes]

    self.default_term_values = { language: ['http://id.loc.gov/vocabulary/iso639-2/eng'] }

    # Add overrides for required properties which are becoming single-valued

    def title
      super.first || ''
    end

    def license
      super.first || ''
    end

    delegate :advisors_attributes=, to: :model
    delegate :arrangers_attributes=, to: :model
    delegate :composers_attributes=, to: :model
    delegate :contributors_attributes=, to: :model
    delegate :creators_attributes=, to: :model
    delegate :project_directors_attributes=, to: :model
    delegate :researchers_attributes=, to: :model
    delegate :reviewers_attributes=, to: :model
    delegate :translators_attributes=, to: :model

    def advisors
      model.advisors.build if model.advisors.blank?
      model.advisors.to_a
    end

    def arrangers
      model.arrangers.build if model.arrangers.blank?
      model.arrangers.to_a
    end

    def composers
      model.composers.build if model.composers.blank?
      model.composers.to_a
    end

    def contributors
      model.contributors.build if model.contributors.blank?
      model.contributors.to_a
    end

    def creators
      model.creators.build if model.creators.blank?
      model.creators.to_a
    end

    def project_directors
      model.project_directors.build if model.project_directors.blank?
      model.project_directors.to_a
    end

    def researchers
      model.researchers.build if model.researchers.blank?
      model.researchers.to_a
    end

    def reviewers
      model.reviewers.build if model.reviewers.blank?
      model.reviewers.to_a
    end

    def translators
      model.translators.build if model.translators.blank?
      model.translators.to_a
    end

    def self.build_permitted_params
      permitted = super
      permitted << { advisors_attributes: [:id, :index, :name, :affiliation, :orcid, :other_affiliation, :_destroy] }
      permitted << { arrangers_attributes: [:id, :index, :name, :affiliation, :orcid, :other_affiliation, :_destroy] }
      permitted << { composers_attributes: [:id, :index, :name, :affiliation, :orcid, :other_affiliation, :_destroy] }
      permitted << { contributors_attributes: [:id, :index, :name, :affiliation, :orcid, :other_affiliation, :_destroy] }
      permitted << { creators_attributes: [:id, :name, :index, :affiliation, :orcid, :other_affiliation, :_destroy] }
      permitted << { project_directors_attributes: [:id, :index, :name, :affiliation, :orcid, :other_affiliation, :_destroy] }
      permitted << { researchers_attributes: [:id, :index, :name, :affiliation, :orcid, :other_affiliation, :_destroy] }
      permitted << { reviewers_attributes: [:id, :index, :name, :affiliation, :orcid, :other_affiliation, :_destroy] }
      permitted << { translators_attributes: [:id, :index, :name, :affiliation, :orcid, :other_affiliation, :_destroy] }
      permitted
    end
  end
end
