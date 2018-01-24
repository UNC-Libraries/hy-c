# Generated via
#  `rails generate hyrax:work Article`
module Hyrax
  class ArticlePresenter < Hyrax::WorkShowPresenter
    delegate :doi, :date_published, :degree_granting_institution, :citation, to: :solr_document
  end
end