# frozen_string_literal: true
module Hyrax
  module SharedDelegates
    extend ActiveSupport::Concern
    included do
      delegate :abstract, :admin_note, :alternative_title, :bibliographic_citation, :contributor, :contributor_display, :copyright_date,
             :creator, :creator_display, :date_created, :date_issued, :dcmi_type, :deposit_record, :description, :doi, :embargo_release_date,
             :extent, :funder, :human_readable_type, :identifier, :itemtype, :kind_of_data, :language, :language_label, :last_modified_date,
             :lease_expiration_date, :license, :license_label, :member_ids, :member_of_collection_ids, :methodology, :note, :orcid_label,
             :other_affiliation_label, :place_of_publication, :project_director_display, :publisher, :related_url, :rendering_ids, :representative_id, :researcher_display,
             :resource_type, :rights_holder, :rights_notes, :rights_statement, :rights_statement_label, :sponsor, :source, :subject,
             :thumbnail_id, :title, to: :solr_document

      delegate :export_as_oai_dc_xml, to: :solr_document
    end
  end
end
