# Generated via
#  `rails generate hyrax:work Article`
module Hyrax
  class ArticlePresenter < Hyrax::WorkShowPresenter
    delegate :doi, :date_published, :institution, :citation, to: :solr_document
  end
end