# Generated via
#  `rails generate hyrax:work DataSet`
module Hyrax
  class DataSetForm < ::SingleValueForm
    class_attribute :single_value_fields

    self.model_class = ::DataSet

    self.terms += [:resource_type, :abstract, :date_issued, :dcmi_type, :doi, :extent, :funder, :geographic_subject,
                   :kind_of_data, :last_modified_date, :project_director, :researcher, :rights_holder, :sponsor]

    self.terms -= [:based_near, :bibliographic_citation, :publisher, :source, :identifier]

    self.required_fields = [:title, :creator, :date_issued, :abstract, :description, :kind_of_data, :resource_type]

    self.single_value_fields = [:title, :license]
    
    self.admin_only_terms = [:dcmi_type, :access, :date_created, :doi, :extent]
    self.default_term_values = { :dcmi_type => ["http://purl.org/dc/dcmitype/Dataset"], :rights_statement => "http://rightsstatements.org/vocab/InC/1.0/",
                                 :language => ["http://id.loc.gov/vocabulary/iso639-2/eng"] }

    # Add overrides for required properties which are becoming single-valued

    def title
      super.first || ""
    end

    def license
      super.first || ""
    end


    delegate :contributors_attributes=, to: :model
    delegate :creators_attributes=, to: :model
    delegate :project_directors_attributes=, to: :model
    delegate :researchers_attributes=, to: :model

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

    def self.build_permitted_params
      permitted = super
      permitted << { contributors_attributes: [:id, :name, :affiliation, :orcid, :other_affiliation, :_destroy] }
      permitted << { creators_attributes: [:id, :name, :affiliation, :orcid, :other_affiliation, :_destroy] }
      permitted << { project_directors_attributes: [:id, :name, :affiliation, :orcid, :other_affiliation, :_destroy] }
      permitted << { researchers_attributes: [:id, :name, :affiliation, :orcid, :other_affiliation, :_destroy] }
      permitted
    end
  end
end
