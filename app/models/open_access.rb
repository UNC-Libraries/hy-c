# Generated via
#  `rails generate hyrax:work OpenAccess`
class OpenAccess < ActiveFedora::Base
  include ::Hyrax::WorkBehavior

  self.indexer = OpenAccessIndexer
  # Change this to restrict which works can be added as a child.
  # self.valid_child_concerns = []
  validates :title, presence: { message: 'Your work must have a title.' }

  self.human_readable_type = 'Open Access'

  property :academic_department, predicate: ::RDF::URI("http://vivoweb.org/ontology/core#AcademicDepartment") do |index|
    index.as :stored_searchable
  end

  property :additional_funding,
           predicate: ::RDF::URI("http://vivoweb.org/ontology/core#FundingOrganization") do |index|
    index.as :stored_searchable
  end

  property :author_status, predicate: ::RDF::URI("http://vivoweb.org/ontology/core#Position"),
           multiple: false do |index|
    index.as :stored_searchable
  end

  property :coauthor, predicate: ::RDF::Vocab::DC11.contributor do |index|
    index.as :stored_searchable
  end

  property :granting_agency, predicate: ::RDF::Vocab::MARCRelators.fnd do |index|
    index.as :stored_searchable
  end

  property :issue, predicate: ::RDF::Vocab::MODS.edition do |index|
    index.as :stored_searchable
  end

  property :link_to_publisher_version, predicate: ::RDF::RDFS.seeAlso do |index|
    index.as :stored_searchable
  end

  property :orcid, predicate: ::RDF::Vocab::Identifiers.orcid do |index|
    index.as :stored_searchable
  end

  property :publication, predicate: ::RDF::Vocab::DC11.publisher do |index|
    index.as :stored_searchable
  end

  property :publication_date, predicate: ::RDF::Vocab::DC.issued do |index|
    index.as :stored_searchable
  end

  property :publication_version, predicate: ::RDF::Vocab::DC.isVersionOf, multiple: false do |index|
    index.as :stored_searchable
  end

  # This must be included at the end, because it finalizes the metadata
  # schema (by adding accepts_nested_attributes)
  include ::Hyrax::BasicMetadata
end
