# Generated via
#  `rails generate hyrax:work General`
class General < ActiveFedora::Base
  include ::Hyrax::WorkBehavior

  self.indexer = GeneralIndexer
  # Change this to restrict which works can be added as a child.
  # self.valid_child_concerns = []
  validates :title, presence: { message: 'Your work must have a title.' }

  self.human_readable_type = 'General'

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

  property :alternative_title, predicate: ::RDF::Vocab::DC.alternative do |index|
    index.as :stored_searchable
  end

  property :arrangers, predicate: ::RDF::URI('http://id.loc.gov/vocabulary/relators/arr'), class_name: 'Person' do |index|
    index.as :stored_searchable
  end

  property :arranger_display, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#ArrangerDisplay') do |index|
    index.as :stored_searchable
  end

  property :award, predicate: ::RDF::Vocab::SCHEMA.award, multiple: false do |index|
    index.as :stored_searchable
  end

  property :composers, predicate: ::RDF::URI('http://id.loc.gov/vocabulary/relators/cmp'), class_name: 'Person' do |index|
    index.as :stored_searchable
  end

  property :composer_display, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#ComposerDisplay') do |index|
    index.as :stored_searchable
  end

  property :conference_name, predicate: ::RDF::Vocab::EBUCore.eventName do |index|
    index.as :stored_searchable
  end

  property :copyright_date, predicate: ::RDF::Vocab::DC.dateCopyrighted do |index|
    index.as :stored_searchable
  end

  property :date_captured, predicate: ::RDF::Vocab::MODS.dateCaptured, multiple: false do |index|
    index.as :stored_searchable
  end

  property :date_issued, predicate: ::RDF::Vocab::DC.issued do |index|
    index.as :stored_searchable, :facetable
  end

  property :date_other, predicate: ::RDF::Vocab::DC.date do |index|
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

  property :digital_collection, predicate: ::RDF::URI('http://dbpedia.org/ontology/collection') do |index|
    index.as :stored_searchable
  end

  property :doi, predicate: ::RDF::Vocab::Identifiers.doi, multiple: false do |index|
    index.as :stored_searchable
  end

  property :edition, predicate: ::RDF::Vocab::BF2.editionStatement do |index|
    index.as :stored_searchable, :facetable
  end

  property :extent, predicate: ::RDF::URI('http://rdaregistry.info/Elements/w/extent.en') do |index|
    index.as :stored_searchable
  end

  property :funders, predicate: ::RDF::URI('http://id.loc.gov/vocabulary/relators/fnd'), class_name: 'Person' do |index|
    index.as :stored_searchable
  end

  property :funder_display, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#FunderDisplay') do |index|
    index.as :stored_searchable
  end

  property :geographic_subject, predicate: ::RDF::Vocab::DC.spatial do |index|
    index.as :stored_searchable
  end

  property :graduation_year, predicate: ::RDF::URI('http://rdaregistry.info/Elements/w/yearDegreeGranted.en'),
           multiple: false do |index|
    index.as :stored_searchable
  end

  property :isbn, predicate: ::RDF::Vocab::Identifiers.isbn do |index|
    index.as :stored_searchable
  end

  property :issn, predicate: ::RDF::Vocab::Identifiers.issn do |index|
    index.as :stored_searchable
  end

  property :journal_issue, predicate: ::RDF::Vocab::BIBO.issue, multiple: false do |index|
    index.as :stored_searchable
  end

  property :journal_title, predicate: ::RDF::URI('http://rdaregistry.info/Elements/w/containedIn.en'),
           multiple: false do |index|
    index.as :stored_searchable
  end

  property :journal_volume, predicate: ::RDF::Vocab::BIBO.volume, multiple: false do |index|
    index.as :stored_searchable
  end

  property :kind_of_data, predicate: ::RDF::Vocab::DISCO.kindOfData do |index|
    index.as :stored_searchable
  end

  property :language_label, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#LanguageLabel') do |index|
    index.as :stored_searchable
  end

  property :last_modified_date, predicate: ::RDF::Vocab::MODS.dateModified, multiple: false do |index|
    index.as :stored_searchable
  end

  property :license_label, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#LicenseLabel') do |index|
    index.as :stored_searchable
  end

  property :medium, predicate: ::RDF::Vocab::DC11.format do |index|
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

  property :page_end, predicate: ::RDF::Vocab::SCHEMA.pageEnd, multiple: false do |index|
    index.as :stored_searchable
  end

  property :page_start, predicate: ::RDF::Vocab::SCHEMA.pageStart, multiple: false do |index|
    index.as :stored_searchable
  end

  property :peer_review_status, predicate: ::RDF::URI('http://purl.org/ontology/bibo/status/peerReviewed'),
           multiple: false do |index|
    index.as :stored_searchable
  end

  property :person_label, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#PersonLabel') do |index|
    index.as :stored_searchable
  end

  property :place_of_publication, predicate: ::RDF::URI('http://id.loc.gov/vocabulary/relators/pup') do |index|
    index.as :stored_searchable
  end

  property :project_directors, predicate: ::RDF::URI('http://id.loc.gov/vocabulary/relators/pdr'), class_name: 'Person' do |index|
    index.as :stored_searchable
  end

  property :project_director_display, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#ProjectDirectorDisplay') do |index|
    index.as :stored_searchable
  end

  property :publisher_version, predicate: ::RDF::Vocab::DC.hasVersion do |index|
    index.as :stored_searchable
  end

  property :researchers, predicate: ::RDF::URI('http://id.loc.gov/vocabulary/relators/res'), class_name: 'Person' do |index|
    index.as :stored_searchable
  end

  property :researcher_display, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#ResearcherDisplay') do |index|
    index.as :stored_searchable
  end

  property :reviewers, predicate: ::RDF::URI('http://id.loc.gov/vocabulary/relators/rev'), class_name: 'Person' do |index|
    index.as :stored_searchable
  end

  property :reviewer_display, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#ReviewerDisplay') do |index|
    index.as :stored_searchable
  end

  property :rights_holder, predicate: ::RDF::Vocab::DC.rightsHolder do |index|
    index.as :stored_searchable
  end

  property :rights_statement_label, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#RightsStatementLabel') do |index|
    index.as :stored_searchable
  end

  property :series, predicate: ::RDF::Vocab::BF2.seriesStatement do |index|
    index.as :stored_searchable
  end

  property :sponsors, predicate: ::RDF::URI('http://id.loc.gov/vocabulary/relators/spn'), class_name: 'Person' do |index|
    index.as :stored_searchable
  end

  property :sponsor_display, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#SponsorDisplay') do |index|
    index.as :stored_searchable
  end

  property :table_of_contents, predicate: ::RDF::Vocab::DC.tableOfContents do |index|
    index.as :stored_searchable
  end

  property :translators, predicate: ::RDF::URI('http://id.loc.gov/vocabulary/relators/trl'), class_name: 'Person' do |index|
    index.as :stored_searchable
  end

  property :translator_display, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#TranslatorDisplay') do |index|
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
  accepts_nested_attributes_for :advisors, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :arrangers, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :creators, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :composers, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :contributors, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :funders, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :project_directors, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :researchers, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :reviewers, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :sponsors, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :translators, allow_destroy: true, reject_if: :all_blank
end
