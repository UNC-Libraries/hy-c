# Generated via
#  `rails generate hyrax:work Dissertation`
class Dissertation < ActiveFedora::Base
  include ::Hyrax::WorkBehavior

  self.indexer = DissertationIndexer
  # Change this to restrict which works can be added as a child.
  # self.valid_child_concerns = []
  validates :title, presence: { message: 'Your work must have a title.' }

  self.human_readable_type = 'Dissertation'

  property :academic_concentration, predicate: ::RDF::URI('http://vivoweb.org/ontology/core#majorField'),
           multiple: true do |index|
    index.as :stored_searchable
  end

  property :advisor, predicate: ::RDF::URI('http://id.loc.gov/vocabulary/relators/ths'), multiple: false do |index|
    index.as :stored_searchable
  end

  property :citation, predicate: ::RDF::Vocab::DC.bibliographicCitation, multiple: false do |index|
    index.as :stored_searchable
  end

  property :date_published, predicate: ::RDF::Vocab::DC.issued, multiple: false do |index|
    index.as :stored_searchable
  end

  property :degree, predicate: ::RDF::Vocab::BIBO.degree, multiple: false do |index|
    index.as :stored_searchable
  end

  property :degree_granting_institution, predicate: ::RDF::URI('http://id.loc.gov/vocabulary/relators/ddg'),
           multiple: true do |index|
    index.as :stored_searchable
  end

  property :graduation_year, predicate: ::RDF::URI('http://rdaregistry.info/Elements/w/yearDegreeGranted.en'),
           multiple: false do |index|
    index.as :stored_searchable
  end

  # This must be included at the end, because it finalizes the metadata
  # schema (by adding accepts_nested_attributes)
  include ::Hyrax::BasicMetadata
end
