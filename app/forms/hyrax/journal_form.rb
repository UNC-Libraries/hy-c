# Generated via
#  `rails generate hyrax:work Journal`
module Hyrax
  class JournalForm < ::SingleValueForm
    class_attribute :single_value_fields
    
    self.model_class = ::Journal

    self.terms += [:abstract, :alternative_title, :date_issued, :dcmi_type, :doi, :extent, :geographic_subject, :isbn,
                   :issn, :note, :place_of_publication, :publisher, :series, :table_of_contents, :resource_type]

    self.terms -= [:description, :based_near, :related_url, :identifier, :contributor, :source, :date_created]

    self.required_fields = [:title, :date_issued, :publisher]

    self.single_value_fields = [:title, :license]
    
    self.admin_only_terms = [:dcmi_type, :access, :alternative_title, :date_created, :doi, :use]
    self.default_term_values = { :dcmi_type => ["http://purl.org/dc/dcmitype/Text"], :language => ["http://id.loc.gov/vocabulary/iso639-2/eng"],
                                 :rights_statement => "http://rightsstatements.org/vocab/InC/1.0/" }

    # Add overrides for required properties which are becoming single-valued

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
      permitted << { creators_attributes: [:id, :name, :affiliation, :orcid, :other_affiliation, :_destroy] }
      permitted
    end
  end
end
