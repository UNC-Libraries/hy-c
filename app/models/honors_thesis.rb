# Generated via
#  `rails generate hyrax:work HonorsThesis`
class HonorsThesis < ActiveFedora::Base
  include ::Hyrax::WorkBehavior

  self.indexer = HonorsThesisIndexer
  # Change this to restrict which works can be added as a child.
  # self.valid_child_concerns = []
  validates :title, presence: { message: 'Your work must have a title.' }

  property :abstract, predicate: ::RDF::Vocab::DC.abstract do |index|
    index.as :stored_searchable
  end

  property :academic_concentration, predicate: ::RDF::URI('http://vivoweb.org/ontology/core#majorField') do |index|
    index.as :stored_searchable
  end

  property :access, predicate: ::RDF::Vocab::DC.accessRights, multiple: false do |index|
    index.as :stored_searchable
  end

  property :admin_note, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#AdminNote'), multiple: false do |index|
    index.as :stored_searchable
  end

  property :advisors, predicate: ::RDF::URI('http://id.loc.gov/vocabulary/relators/ths'), class_name: 'Person' do |index|
    index.as :stored_searchable
  end

  property :alternative_title, predicate: ::RDF::Vocab::DC.alternative do |index|
    index.as :stored_searchable
  end

  property :award, predicate: ::RDF::Vocab::SCHEMA.award, multiple: false do |index|
    index.as :stored_searchable
  end

  property :date_issued, predicate: ::RDF::Vocab::DC.issued, multiple: false do |index|
    index.as :stored_searchable
  end

  property :dcmi_type, predicate: ::RDF::Vocab::DC.type do |index|
    index.as :stored_searchable
  end

  property :degree, predicate: ::RDF::Vocab::BIBO.degree, multiple: false do |index|
    index.as :stored_searchable
  end

  property :degree_granting_institution, predicate: ::RDF::URI('http://id.loc.gov/vocabulary/relators/dgg'),
           multiple: false do |index|
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

  property :graduation_year, predicate: ::RDF::URI('http://rdaregistry.info/Elements/u/yearDegreeGranted.en'),
           multiple: false do |index|
    index.as :stored_searchable
  end

  property :language_label, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#LanguageLabel') do |index|
    index.as :stored_searchable
  end

  property :license_label, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#LicenseLabel') do |index|
    index.as :stored_searchable
  end

  property :note, predicate: ::RDF::Vocab::SKOS.note do |index|
    index.as :stored_searchable
  end
  
  property :rights_statement_label, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#RightsStatementLabel'), multiple: false do |index|
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

  # accepts_nested_attributes_for can not be called until all
  # the properties are declared because it calls resource_class,
  # which finalizes the property declarations.
  # See https://github.com/projecthydra/active_fedora/issues/847
  accepts_nested_attributes_for :advisors, allow_destroy: true, reject_if: proc { |attributes| attributes['name'].blank? }
  accepts_nested_attributes_for :creators, allow_destroy: true, reject_if: proc { |attributes| attributes['name'].blank? }
end
