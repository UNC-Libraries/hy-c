# Generated via
#  `rails generate hyrax:work ScholarlyWork`
class ScholarlyWork < ActiveFedora::Base
  include ::Hyrax::WorkBehavior

  self.indexer = ScholarlyWorkIndexer
  # Change this to restrict which works can be added as a child.
  # self.valid_child_concerns = []
  validates :title, presence: { message: 'Your work must have a title.' }

  self.human_readable_type = 'Scholarly Work'

  property :abstract, predicate: ::RDF::Vocab::DC.abstract do |index|
    index.as :stored_searchable
  end

  property :advisor, predicate: ::RDF::URI('http://id.loc.gov/vocabulary/relators/ths') do |index|
    index.as :stored_searchable, :facetable
  end

  property :affiliation, predicate: ::RDF::Vocab::SCHEMA.affiliation do |index|
    index.as :stored_searchable, :facetable
  end

  property :affiliation_label, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#AffiliationLabel') do |index|
    index.as :stored_searchable, :facetable
  end

  property :conference_name, predicate: ::RDF::Vocab::EBUCore.eventName do |index|
    index.as :stored_searchable
  end

  property :date_issued, predicate: ::RDF::Vocab::DC.issued, multiple: false do |index|
    index.as :stored_searchable, :facetable
  end

  property :dcmi_type, predicate: ::RDF::Vocab::DC.type do |index|
    index.as :stored_searchable
  end

  # link to previous deposit record
  property :deposit_record, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#DepositRecord'), multiple: false do |index|
    index.as :stored_searchable
  end

  property :doi, predicate: ::RDF::Vocab::Identifiers.doi, multiple: false do |index|
    index.as :stored_searchable
  end

  property :geographic_subject, predicate: ::RDF::Vocab::DC.spatial do |index|
    index.as :stored_searchable
  end

  property :language_label, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#LanguageLabel') do |index|
    index.as :stored_searchable
  end

  property :license_label, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#LicenseLabel') do |index|
    index.as :stored_searchable
  end

  property :orcid, predicate: ::RDF::Vocab::Identifiers.orcid do |index|
    index.as :stored_searchable
  end

  property :other_affiliation, predicate: ::RDF::Vocab::EBUCore.hasAffiliation do |index|
    index.as :stored_searchable
  end

  property :rights_statement_label, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#RightsStatementLabel'), multiple: false do |index|
    index.as :stored_searchable
  end

  # This must be included at the end, because it finalizes the metadata
  # schema (by adding accepts_nested_attributes)
  include ::Hyrax::BasicMetadata
end
