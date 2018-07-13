# Generated via
#  `rails generate hyrax:work DataSet`
class DataSet < ActiveFedora::Base
  include ::Hyrax::WorkBehavior

  self.indexer = DataSetIndexer
  # Change this to restrict which works can be added as a child.
  # self.valid_child_concerns = []
  validates :title, presence: { message: 'Your work must have a title.' }

  self.human_readable_type = 'Dataset'

  property :abstract, predicate: ::RDF::Vocab::DC.abstract do |index|
    index.as :stored_searchable
  end

  property :copyright_date, predicate: ::RDF::Vocab::DC.dateCopyrighted, multiple: false do |index|
    index.as :stored_searchable
  end

  property :date_issued, predicate: ::RDF::Vocab::DC.issued, multiple: false do |index|
    index.as :stored_searchable
  end

  # link to previous deposit record
  property :deposit_record, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#DepositRecord'), multiple: false do |index|
    index.as :stored_searchable
  end

  property :doi, predicate: ::RDF::Vocab::Identifiers.doi, multiple: false do |index|
    index.as :stored_searchable
  end

  property :extent, predicate: ::RDF::URI('http://rdaregistry.info/Elements/u/extent.en') do |index|
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

  property :kind_of_data, predicate: ::RDF::Vocab::DISCO.kindOfData do |index|
    index.as :stored_searchable
  end

  property :last_modified_date, predicate: ::RDF::Vocab::MODS.dateModified, multiple: false do |index|
    index.as :stored_searchable
  end

  property :project_director, predicate: ::RDF::URI('http://id.loc.gov/vocabulary/relators/pdr') do |index|
    index.as :stored_searchable
  end

  property :researcher, predicate: ::RDF::URI('http://id.loc.gov/vocabulary/relators/res') do |index|
    index.as :stored_searchable
  end

  property :rights_holder, predicate: ::RDF::Vocab::DC.rightsHolder do |index|
    index.as :stored_searchable
  end

  property :sponsor, predicate: ::RDF::URI('http://id.loc.gov/vocabulary/relators/spn') do |index|
    index.as :stored_searchable
  end

  # This must be included at the end, because it finalizes the metadata
  # schema (by adding accepts_nested_attributes)
  include ::Hyrax::BasicMetadata
end
