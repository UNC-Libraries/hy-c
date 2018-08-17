# Generated via
#  `rails generate hyrax:work MastersPaper`
module Hyrax
  class MastersPaperPresenter < Hyrax::WorkShowPresenter
    delegate :abstract, :academic_concentration, :access, :advisor, :affiliation, :date_issued, :dcmi_type, :degree,
             :degree_granting_institution, :deposit_record, :doi, :extent, :geographic_subject, :graduation_year,
             :note, :reviewer, :use, to: :solr_document
  end
end
