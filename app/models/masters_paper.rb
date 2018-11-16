# Generated via
#  `rails generate hyrax:work MastersPaper`
class MastersPaper < ActiveFedora::Base
  include ::Hyrax::WorkBehavior

  self.indexer = MastersPaperIndexer
  # Change this to restrict which works can be added as a child.
  # self.valid_child_concerns = []
  validates :title, presence: { message: 'Your work must have a title.' }

  self.human_readable_type = "Master's Paper"

  property :abstract, predicate: ::RDF::Vocab::DC.abstract do |index|
    index.as :stored_searchable
  end

  property :academic_concentration, predicate: ::RDF::URI('http://vivoweb.org/ontology/core#majorField') do |index|
    index.as :stored_searchable
  end

  property :access, predicate: ::RDF::Vocab::DC.accessRights, multiple: false do |index|
    index.as :stored_searchable
  end

  property :advisors, predicate: ::RDF::URI('http://id.loc.gov/vocabulary/relators/ths'), class_name: 'Person' do |index|
    index.as :stored_searchable
  end

  property :advisor_display, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#AdvisorDisplay') do |index|
    index.as :stored_searchable
  end

  property :affiliation_label, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#AffiliationLabel') do |index|
    index.as :stored_searchable, :facetable
  end

  property :date_issued, predicate: ::RDF::Vocab::DC.issued, multiple: false do |index|
    index.as :stored_searchable, :facetable
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

  property :geographic_subject, predicate: ::RDF::Vocab::DC.spatial do |index|
    index.as :stored_searchable
  end

  property :graduation_year, predicate: ::RDF::URI('http://rdaregistry.info/Elements/w/yearDegreeGranted.en'),
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

  property :orcid_label, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#OrcidLabel') do |index|
    index.as :stored_searchable
  end

  property :other_affiliation_label, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#OtherAffiliationLabel') do |index|
    index.as :stored_searchable
  end

  property :reviewers, predicate: ::RDF::URI('http://id.loc.gov/vocabulary/relators/rev'), class_name: 'Person' do |index|
    index.as :stored_searchable
  end

  property :reviewer_display, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#ReviewerDisplay') do |index|
    index.as :stored_searchable
  end

  property :rights_statement_label, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#RightsStatementLabel') do |index|
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
  accepts_nested_attributes_for :advisors, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :creators, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :reviewers, allow_destroy: true, reject_if: :all_blank
end
