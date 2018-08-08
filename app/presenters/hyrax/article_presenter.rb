# Generated via
#  `rails generate hyrax:work Article`
module Hyrax
  class ArticlePresenter < Hyrax::WorkShowPresenter
    delegate :abstract, :access, :affiliation, :bibliographic_citation, :copyright_date, :date_captured,
             :date_issued, :date_other, :dcmi_type, :deposit_record, :doi, :edition, :extent, :funder, :geographic_subject,
             :issn, :journal_issue, :journal_title, :journal_volume, :note, :page_end, :page_start, :peer_review_status,
             :place_of_publication, :rights_holder, :table_of_contents, :translator, :url, :use, to: :solr_document
  end
end
