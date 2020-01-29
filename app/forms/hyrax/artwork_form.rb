# Generated via
#  `rails generate hyrax:work Artwork`
module Hyrax
  # Generated form for Artwork
  class ArtworkForm < ::SingleValueForm

    class_attribute :single_value_fields

    self.model_class = ::Artwork
    self.terms += [:resource_type, :abstract, :admin_note, :dcmi_type, :date_issued, :note, :doi, :extent, :medium,
                   :deposit_agreement, :agreement]
    self.terms -= [:contributor, :keyword, :publisher, :subject, :language, :identifier, :based_near,
                   :related_url, :source, :language_label, :date_created]
    self.required_fields = [:title, :date_issued, :abstract, :extent, :medium, :resource_type]

    # Add overrides for required properties which are becoming single-valued
    self.single_value_fields = [:title, :license]
    self.admin_only_terms = [:admin_note, :dcmi_type, :doi]
    self.default_term_values = { :dcmi_type => ["http://purl.org/dc/dcmitype/Image"],
                                 :rights_statement => "http://rightsstatements.org/vocab/InC/1.0/" }

    def title
      super.first || ""
    end

    def license
      super.first || ""
    end

    delegate :creators_attributes=, to: :model

    def creators
      model.creators.build if model.creators.blank?
      model.creators.to_a
    end

    def self.build_permitted_params
      permitted = super
      permitted << { creators_attributes: [:id, :index, :name, :affiliation, :orcid, :other_affiliation, :_destroy] }
      permitted
    end
  end
end
