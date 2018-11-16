# Generated via
#  `rails generate hyrax:work Article`
module Hyrax
  class ArticleForm < ::SingleValueForm

    class_attribute :single_value_fields

    self.model_class = ::Article
    self.terms += [:resource_type, :abstract, :access, :bibliographic_citation, :copyright_date, :date_captured,
                   :date_issued, :date_other, :dcmi_type, :doi, :edition, :extent, :funder, :geographic_subject, :issn,
                   :journal_issue, :journal_title, :journal_volume, :note, :page_end, :page_start, :peer_review_status,
                   :place_of_publication, :rights_holder, :table_of_contents, :translator, :url, :use]

    self.required_fields = [:title, :creator, :abstract, :date_issued]

    self.terms -= [:contributor, :based_near, :source, :description]
    
    self.single_value_fields = [:title, :license, :rights_statement]
    
    self.admin_only_terms = [:dcmi_type]
    self.default_term_values = { :dcmi_type => ["http://purl.org/dc/dcmitype/Text"] }

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


    delegate :creators_attributes=, to: :model
    delegate :funders_attributes=, to: :model
    delegate :translators_attributes=, to: :model

    def creators
      model.creators.build if model.creators.blank?
      model.creators.to_a
    end

    def funders
      model.funders.build if model.funders.blank?
      model.funders.to_a
    end

    def translators
      model.translators.build if model.translators.blank?
      model.translators.to_a
    end

    def self.build_permitted_params
      permitted = super
      permitted << { creators_attributes: [:id, :name, :affiliation, :orcid, :other_affiliation, :_destroy] }
      permitted << { funders_attributes: [:id, :name, :affiliation, :orcid, :other_affiliation, :_destroy] }
      permitted << { translators_attributes: [:id, :name, :affiliation, :orcid, :other_affiliation, :_destroy] }
      permitted
    end
  end
end
