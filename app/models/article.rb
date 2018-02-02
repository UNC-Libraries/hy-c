# Generated via
#  `rails generate hyrax:work Article`
class Article < ActiveFedora::Base
  include ::Hyrax::WorkBehavior

  self.indexer = ArticleIndexer
  # Change this to restrict which works can be added as a child.
  # self.valid_child_concerns = []
  validates :title, presence: { message: 'Your work must have a title.' }

  self.human_readable_type = 'Article'

  property :abstract, predicate: ::RDF::Vocab::DC.abstract do |index|
    index.as :stored_searchable
  end

  property :access, predicate: ::RDF::Vocab::DC.accessRights, multiple: false do |index|
    index.as :stored_searchable
  end

  property :affiliation, predicate: ::RDF::URI('http://vivoweb.org/ontology/core#AcademicDepartment') do |index|
    index.as :stored_searchable
  end

  property :citation, predicate: ::RDF::Vocab::DC.bibliographicCitation do |index|
    index.as :stored_searchable
  end

  property :copyright_date, predicate: ::RDF::Vocab::DC.dateCopyrighted, multiple: false do |index|
    index.as :stored_searchable
  end

  property :date_captured, predicate: ::RDF::Vocab::MODS.dateCaptured, multiple: false do |index|
    index.as :stored_searchable
  end

  property :date_issued, predicate: ::RDF::Vocab::DC.issued, multiple: false do |index|
    index.as :stored_searchable
  end

  property :date_other, predicate: ::RDF::Vocab::DC.date do |index|
    index.as :stored_searchable
  end

  property :doi, predicate: ::RDF::Vocab::Identifiers.doi, multiple: false do |index|
    index.as :stored_searchable
  end

  property :edition, predicate: ::RDF::Vocab::BF2.editionStatement do |index|
    index.as :stored_searchable
  end

  property :extent, predicate: ::RDF::Vocab::DC.extent do |index|
    index.as :stored_searchable
  end

  property :funder, predicate: ::RDF::URI('http://id.loc.gov/vocabulary/relators/fnd') do |index|
    index.as :stored_searchable
  end

  property :genre, predicate: ::RDF::Vocab::EDM.hasType do |index|
    index.as :stored_searchable
  end

  property :geographic_subject, predicate: ::RDF::Vocab::DC.spatial do |index|
    index.as :stored_searchable
  end

  property :issn, predicate: ::RDF::Vocab::Identifiers.issn do |index|
    index.as :stored_searchable
  end

  property :journal_issue, predicate: ::RDF::Vocab::BIBO::issue, multiple: false do |index|
    index.as :stored_searchable
  end

 # property :journal_title, predicate: ::RDF::Vocab::BIBO::issue, multiple: false do |index|
 #   index.as :stored_searchable
 # end

  property :journal_volume, predicate: ::RDF::Vocab::BIBO::volume, multiple: false do |index|
    index.as :stored_searchable
  end

  property :note, predicate: ::RDF::Vocab::SKOS.note do |index|
    index.as :stored_searchable
  end

  property :orcid, predicate: ::RDF::Vocab::Identifiers.orcid do |index|
    index.as :stored_searchable
  end

  property :other_affiliation, predicate: ::RDF::URI('http://schema.org/affiliation') do |index|
    index.as :stored_searchable
  end

  property :page_end, predicate: ::RDF::Vocab::SCHEMA.pageEnd, multiple: false do |index|
    index.as :stored_searchable
  end

  property :page_start, predicate: ::RDF::Vocab::SCHEMA.pageStart, multiple: false do |index|
    index.as :stored_searchable
  end

  property :peer_review_status, predicate: ::RDF::Vocab::BIBO.status/peerReviewed, multiple: false do |index|
    index.as :stored_searchable
  end

  property :place_of_publication, predicate: ::RDF::URI('http://id.loc.gov/vocabulary/relators/pup') do |index|
    index.as :stored_searchable
  end

  property :rights_holder, predicate: ::RDF::Vocab::DC.rightsHolder do |index|
    index.as :stored_searchable
  end

  property :table_of_contents, predicate: ::RDF::Vocab::DC.tableOfContents do |index|
    index.as :stored_searchable
  end

  property :translator, predicate: ::RDF::URI('http://id.loc.gov/vocabulary/relators/trl'), multiple: true do |index|
    index.as :stored_searchable
  end

  property :url, predicate: ::RDF::Vocab::SCHEMA.url do |index|
    index.as :stored_searchable
  end

  property :use, predicate: ::RDF::Vocab::DC11.rights do |index|
    index.as :stored_searchable
  end

  # This must be included at the end, because it finalizes the metadata
  # schema (by adding accepts_nested_attributes)
  include ::Hyrax::BasicMetadata

end