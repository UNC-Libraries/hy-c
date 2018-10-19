# Generated via
#  `rails generate hyrax:work ArtWork`
class ArtWork < ActiveFedora::Base
  include ::Hyrax::WorkBehavior

  self.indexer = ArtWorkIndexer
  # Change this to restrict which works can be added as a child.
  # self.valid_child_concerns = []
  validates :title, presence: { message: 'Your work must have a title.' }

  self.human_readable_type = 'Art Work'

  property :doi, predicate: ::RDF::Vocab::Identifiers.doi, multiple: false do |index|
    index.as :stored_searchable
  end

  property :extent, predicate: ::RDF::URI('http://rdaregistry.info/Elements/w/extent.en'), multiple: false do |index|
    index.as :stored_searchable
  end

  property :license_label, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#LicenseLabel') do |index|
    index.as :stored_searchable
  end

  property :medium, predicate: ::RDF::Vocab::DC11.format, multiple: false do  |index|
    index.as :stored_searchable
  end

  property :rights_statement_label, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#RightsStatementLabel') do |index|
    index.as :stored_searchable
  end

  # This must be included at the end, because it finalizes the metadata
  # schema (by adding accepts_nested_attributes)
  include ::Hyrax::BasicMetadata
end
