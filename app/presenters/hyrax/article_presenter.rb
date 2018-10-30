# Generated via
#  `rails generate hyrax:work Article`
module Hyrax
  class ArticlePresenter < Hyrax::WorkShowPresenter
    delegate :abstract, :access, :affiliation, :affiliation_label, :bibliographic_citation, :copyright_date,
             :date_issued, :date_other, :dcmi_type, :deposit_record, :doi, :edition, :extent, :funder,
             :geographic_subject, :issn, :journal_issue, :journal_title, :journal_volume, :language_label,
             :license_label, :note, :orcid, :other_affiliation, :page_end, :page_start, :peer_review_status,
             :place_of_publication, :rights_holder, :rights_statement_label, :translator, :url,
             :use, to: :solr_document
  end
end
