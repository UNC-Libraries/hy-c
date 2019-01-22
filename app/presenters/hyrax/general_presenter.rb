# Generated via
#  `rails generate hyrax:work General`
module Hyrax
  class GeneralPresenter < Hyrax::WorkShowPresenter
    delegate :abstract, :academic_concentration, :access, :advisor_display, :alternative_title, :arranger_display,
             :award, :bibliographic_citation, :composer_display, :conference_name, :contributor_display,
             :copyright_date, :creator_display, :date_issued, :date_other, :dcmi_type, :degree,
             :degree_granting_institution, :deposit_record, :digital_collection, :doi, :edition, :extent,
             :funder, :geographic_subject, :graduation_year, :isbn, :issn, :journal_issue, :journal_title,
             :journal_volume, :kind_of_data, :last_modified_date, :language_label, :license_label, :medium, :methodology,
             :note, :page_start, :page_end, :peer_review_status, :place_of_publication, :publisher_version,
             :project_director_display, :researcher_display, :reviewer_display, :rights_holder, :rights_statement_label,
             :series, :sponsor, :table_of_contents, :translator_display, :url, :use, to: :solr_document
  end
end
