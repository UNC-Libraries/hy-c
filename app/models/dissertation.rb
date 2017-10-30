# Generated via
#  `rails generate hyrax:work Dissertation`
class Dissertation < ActiveFedora::Base
  include ::Hyrax::WorkBehavior

  self.indexer = DissertationIndexer
  # Change this to restrict which works can be added as a child.
  # self.valid_child_concerns = []
  validates :title, presence: { message: 'Your work must have a title.' }

  self.human_readable_type = 'Dissertation'

  property :author_degree_granted,
           predicate: ::RDF::URI("http://purl.org/ontology/bibo/ThesisDegree"), multiple: false do |index|
    index.as :stored_searchable
  end

  property :author_academic_concentration,
           predicate: ::RDF::URI("http://cdr.lib.unc.edu/concentration"), multiple: true do |index|
    index.as :stored_searchable
  end

  property :institution, predicate: ::RDF::Vocab::DC11.publisher, multiple: true do |index|
    index.as :stored_searchable
  end

  property :author_graduation_date, predicate: ::RDF::Vocab::DC11.date, multiple: false do |index|
    index.as :stored_searchable
  end

  property :date_published, predicate: ::RDF::Vocab::DC.issued, multiple: false do |index|
    index.as :stored_searchable
  end

  property :faculty_advisor_name, predicate: ::RDF::Vocab::MARCRelators.ths, multiple: false do |index|
    index.as :stored_searchable
  end

  # This must be included at the end, because it finalizes the metadata
  # schema (by adding accepts_nested_attributes)
  include ::Hyrax::BasicMetadata
end
