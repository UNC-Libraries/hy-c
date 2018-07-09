# Generated via
#  `rails generate hyrax:work HonorsThesis`
module Hyrax
  class HonorsThesisPresenter < Hyrax::WorkShowPresenter
    delegate :abstract, :academic_concentration, :access, :advisor, :alternative_title, :award,
             :date_issued, :degree, :degree_granting_institution, :deposit_record, :doi, :extent, :genre, :geographic_subject,
             :graduation_year, :note, :use, to: :solr_document
  end
end
