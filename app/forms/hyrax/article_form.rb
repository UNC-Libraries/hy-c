# Generated via
#  `rails generate hyrax:work Article`
module Hyrax
  class ArticleForm < ::SingleValueForm

    class_attribute :single_value_fields

    self.model_class = ::Article

    self.terms += [:resource_type, :abstract, :access, :admin_note, :alternative_title, :bibliographic_citation, :copyright_date,
                   :date_captured, :date_issued, :date_other, :dcmi_type, :digital_collection, :doi, :edition, :extent,
                   :funder, :issn, :journal_title, :journal_volume, :journal_issue, :note, :page_start, :page_end,
                   :peer_review_status, :place_of_publication, :rights_holder, :translator, :use, :deposit_agreement,
                   :agreement]

    self.required_fields = [:title, :creator, :abstract, :date_issued]

    self.terms -= [:contributor, :source, :description, :date_created]

    self.single_value_fields = [:title, :license]

    self.admin_only_terms = [:dcmi_type, :access, :admin_note, :bibliographic_citation, :copyright_date, :date_captured, :date_other,
                             :digital_collection, :doi, :extent, :identifier, :rights_holder, :translator, :use]
    self.default_term_values = { :dcmi_type => ["http://purl.org/dc/dcmitype/Text"],
                                 :language => ["http://id.loc.gov/vocabulary/iso639-2/eng"],
                                 :rights_statement => "http://rightsstatements.org/vocab/InC/1.0/" }

    # Add overrides for required properties which are becoming single-valued

    def title
      super.first || ""
    end

    def license
      super.first || ""
    end

    delegate :creators_attributes=, to: :model
    delegate :translators_attributes=, to: :model

    def creators
      model.creators.build if model.creators.blank?
      model.creators.to_a
    end

    def translators
      model.translators.build if model.translators.blank?
      model.translators.to_a
    end

    def self.build_permitted_params
      permitted = super
      permitted << { creators_attributes: [:id, :index, :name, :affiliation, :orcid, :other_affiliation, :_destroy] }
      permitted << { translators_attributes: [:id, :index, :name, :affiliation, :orcid, :other_affiliation, :_destroy] }
      permitted
    end
  end
end
