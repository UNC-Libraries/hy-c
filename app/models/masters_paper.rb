# Generated via
#  `rails generate hyrax:work MastersPaper`
class MastersPaper < ActiveFedora::Base
  include ::Hyrax::WorkBehavior

  self.indexer = MastersPaperIndexer
  # Change this to restrict which works can be added as a child.
  # self.valid_child_concerns = []
  validates :title, presence: { message: 'Your work must have a title.' }

  self.human_readable_type = 'Masters Paper'

  property :author_degree_granted,
           predicate: ::RDF::URI("http://purl.org/ontology/bibo/ThesisDegree"), multiple: false do |index|
    index.as :stored_searchable
  end

  property :author_graduation_date, predicate: ::RDF::Vocab::DC11.date do |index|
    index.as :stored_searchable
  end

  property :date_published, predicate: ::RDF::Vocab::DC.issued do |index|
    index.as :stored_searchable
  end

  property :faculty_advisor_name, predicate: ::RDF::Vocab::MARCRelators.ths, multiple: false do |index|
    index.as :stored_searchable
  end

  # This must be included at the end, because it finalizes the metadata
  # schema (by adding accepts_nested_attributes)
  include ::Hyrax::BasicMetadata
end
