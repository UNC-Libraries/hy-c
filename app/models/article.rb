# Generated via
#  `rails generate hyrax:work Article`
class Article < ActiveFedora::Base
  include ::Hyrax::WorkBehavior

  self.indexer = ArticleIndexer
  # Change this to restrict which works can be added as a child.
  # self.valid_child_concerns = []
  validates :title, presence: { message: 'Your work must have a title.' }

  self.human_readable_type = 'Article'

  property :citation, predicate: ::RDF::Vocab::DC.bibliographicCitation, multiple: false do |index|
    index.as :stored_searchable
  end

  property :doi,
           predicate: ::RDF::Vocab::MADS.code, multiple: false do |index|
    index.as :stored_searchable
  end

  property :date_published, predicate: ::RDF::Vocab::DC.issued, multiple: false do |index|
    index.as :stored_searchable
  end

  property :degree_granting_institution, predicate: ::RDF::URI('http://id.loc.gov/vocabulary/relators/ddg'),
           multiple: true do |index|
    index.as :stored_searchable
  end

  # This must be included at the end, because it finalizes the metadata
  # schema (by adding accepts_nested_attributes)
  include ::Hyrax::BasicMetadata

end