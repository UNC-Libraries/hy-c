# Generated via
#  `rails generate hyrax:work Article`
module Hyrax
  class ArticlePresenter < Hyrax::WorkShowPresenter
    delegate :abstract, :access, :affiliation, :copyright_date, :date_captured,
             :date_issued, :date_other, :doi, :edition, :extent, :funder, :genre,
             :geographic_subject, :issn, :journal_issue, :journal_title, :journal_volume, :note, :orcid,
             :other_affiliation, :page_end, :page_start, :peer_review_status, :place_of_publication, :rights_holder,
             :table_of_contents, :translator, :url, :use, to: :solr_document
  end
end