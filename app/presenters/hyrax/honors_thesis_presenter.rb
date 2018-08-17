# Generated via
#  `rails generate hyrax:work HonorsThesis`
module Hyrax
  class HonorsThesisPresenter < Hyrax::WorkShowPresenter
    delegate :abstract, :academic_concentration, :access, :advisor, :affiliation, :alternative_title, :award,
             :date_issued, :dcmi_type, :degree, :degree_granting_institution, :deposit_record, :doi, :extent, 
             :geographic_subject, :graduation_year, :note, :url, :use, to: :solr_document
  end
end
