# Generated via
#  `rails generate hyrax:work OpenAccess`
module Hyrax
  class OpenAccessPresenter < Hyrax::WorkShowPresenter
    delegate :academic_department, :additional_funding, :author_status, :coauthor, :granting_agency, :issue,
             :link_to_publisher_version, :orcid, :publication, :publication_date, :publication_version, to: :solr_document
  end
end
