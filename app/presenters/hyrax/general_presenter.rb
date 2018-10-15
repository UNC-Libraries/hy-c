# Generated via
#  `rails generate hyrax:work General`
module Hyrax
  class GeneralPresenter < Hyrax::WorkShowPresenter
    delegate :abstract, :academic_concentration, :access, :advisor, :affiliation, :affiliation_label,
             :alternative_title, :arranger, :award, :bibliographic_citation, :composer, :conference_name,
             :copyright_date, :date_captured, :date_issued, :date_other, :dcmi_type, :degree,
             :degree_granting_institution, :deposit_record, :digital_collection, :doi, :edition, :extent, :funder,
             :geographic_subject, :graduation_year, :isbn, :issn, :journal_issue, :journal_title, :journal_volume,
             :kind_of_data, :last_modified_date, :language_label, :license_label, :medium, :note, :orcid,
             :other_affiliation, :page_start, :page_end, :peer_review_status, :place_of_publication, :publisher_version,
             :project_director, :researcher, :reviewer, :rights_holder, :rights_statement_label, :series, :sponsor,
             :table_of_contents, :translator, :url, :use, to: :solr_document
  end
end
