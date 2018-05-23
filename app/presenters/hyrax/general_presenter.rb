# Generated via
#  `rails generate hyrax:work General`
module Hyrax
  class GeneralPresenter < Hyrax::WorkShowPresenter
    delegate [:alternate_title, :advisor, :funder, :project_director, :researcher, :sponsor,
              :translator, :reviewer, :degree_granting_institution, :conference_name, :orcid, :affiliation,
              :other_affiliation, :date_issued, :copyright_date, :last_modified_date, :date_other, :date_captured,
              :graduation_year, :abstract, :note, :extent, :table_of_contents, :bibliographic_citation, :edition,
              :peer_review_status, :degree, :academic_concentration, :discipline, :award, :medium, :kind_of_data,
              :series, :geographic_subject, :use, :rights_holder, :access, :doi, :issn, :isbn,
              :place_of_publication, :journal_title, :journal_volume, :journal_issue, :page_start, :page_end, :url,
              :digital_collection], to: :solr_document
  end
end
