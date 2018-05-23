# Generated via
#  `rails generate hyrax:work General`
class General < ActiveFedora::Base
  include ::Hyrax::WorkBehavior

  self.indexer = GeneralIndexer
  # Change this to restrict which works can be added as a child.
  # self.valid_child_concerns = []
  validates :title, presence: { message: 'Your work must have a title.' }

  self.human_readable_type = 'General'

  property :alternative_title, predicate: ::RDF::Vocab::DC.alternative do |index|
    index.as :stored_serachable
  end

  property :advisor, predicate: ::RDF::URI('http://id.loc.gov/vocabulary/relators/ths') do |index|
    index.as :stored_serachable
  end

  property :funder, predicate: ::RDF::URI('http://id.loc.gov/vocabulary/relators/fnd') do |index|
    index.as :stored_serachable
  end

  property :project_director, predicate: ::RDF::URI('http://id.loc.gov/vocabulary/relators/pdr') do |index|
    index.as :stored_serachable
  end

  property :researcher, predicate: ::RDF::URI('http://id.loc.gov/vocabulary/relators/res') do |index|
    index.as :stored_serachable
  end

  property :sponsor, predicate: ::RDF::URI('http://id.loc.gov/vocabulary/relators/spn') do |index|
    index.as :stored_serachable
  end

  property :translator, predicate: ::RDF::URI('http://id.loc.gov/vocabulary/relators/trl') do |index|
    index.as :stored_serachable
  end

  property :reviewer, predicate: ::RDF::URI('http://id.loc.gov/vocabulary/relators/rev') do |index|
    index.as :stored_serachable
  end
  property :degree_granting_institution, predicate: ::RDF::URI('http://id.loc.gov/vocabulary/relators/ddg'),
           multiple: false do |index|
    index.as :stored_searchable
  end

  property :conference_name, predicate: ::RDF::Vocab::EBUCore.eventName do |index|
    index.as :stored_serachable
  end

  property :orcid, predicate: ::RDF::Vocab::Identifiers.orcid do |index|
    index.as :stored_serachable
  end

  property :affiliation, predicate: ::RDF::URI('http://vivoweb.org/ontology/core#AcademicDepartment') do |index|
    index.as :stored_serachable
  end

  property :other_affiliation, predicate: ::RDF::Vocab::SCHEMA.affiliation do |index|
    index.as :stored_serachable
  end

  property :date_issued, predicate: ::RDF::Vocab::DC.issued do |index|
    index.as :stored_serachable
  end

  property :copyright_date, predicate: ::RDF::Vocab::DC.dateCopyrighted do |index|
    index.as :stored_searchable
  end

  property :last_date_modified, predicate: ::RDF::Vocab::MODS.dateModified, multiple: false do |index|
    index.as :stored_serachable
  end

  property :date_other, predicate: ::RDF::Vocab::DC.date do |index|
    index.as :stored_serachable
  end

  property :date_captured, predicate: ::RDF::Vocab::MODS.dateCaptured, multiple: false do |index|
    index.as :stored_serachable
  end

  property :graduation_year, predicate: ::RDF::URI('http://rdaregistry.info/Elements/w/yearDegreeGranted.en'),
           multiple: false do |index|
    index.as :stored_serachable
  end

  property :abstract, predicate: ::RDF::Vocab::DC.abstract do |index|
    index.as :stored_serachable
  end

  property :note, predicate: ::RDF::Vocab::SKOS.note do |index|
    index.as :stored_serachable
  end

  property :extent, predicate: ::RDF::URI('http://rdaregistry.info/Elements/w/extent.en') do |index|
    index.as :stored_serachable
  end

  property :table_of_contents, predicate: ::RDF::Vocab::DC.tableOfContents do |index|
    index.as :stored_serachable
  end

  property :citation, predicate: ::RDF::Vocab::DC.bibliographicCitation do |index|
    index.as :stored_serachable
  end

  property :edition, predicate: ::RDF::Vocab::BF2.editionStatement do |index|
    index.as :stored_serachable
  end

  property :peer_review_status, predicate: ::RDF::Vocab::BIBO.peerReviewed, multiple: false do |index|
    index.as :stored_serachable
  end

  property :degree, predicate: ::RDF::Vocab::BIBO.degree, multiple: false do |index|
    index.as :stored_serachable
  end

  property :academic_concentration, predicate: ::RDF::URI('http://vivoweb.org/ontology/core#majorField') do |index|
    index.as :stored_serachable
  end

  property :discipline, predicate: ::RDF::URI('http://dbpedia.org/ontology/academicDiscipline') do |index|
    index.as :stored_serachable
  end

  property :award, predicate: ::RDF::Vocab::SCHEMA.award do |index|
    index.as :stored_serachable
  end

  property :medium, predicate: ::RDF::Vocab::DC.medium do |index|
    index.as :stored_serachable
  end

  property :kind_of_data, predicate: ::RDF::Vocab::DISCO.kindOfData do |index|
    index.as :stored_serachable
  end

  property :series, predicate: ::RDF::Vocab::BF2.seriesStatement do |index|
    index.as :stored_serachable
  end

  property :geographic_subject, predicate: ::RDF::Vocab::DC.spatial do |index|
    index.as :stored_serachable
  end

  property :use, predicate: ::RDF::Vocab::DC11.rights do |index|
    index.as :stored_serachable
  end

  property :rights_holder, predicate: ::RDF::Vocab::DC.rightsHolder do |index|
    index.as :stored_serachable
  end

  property :access, predicate: ::RDF::Vocab::DC.accessRights, multiple: false do |index|
    index.as :stored_serachable
  end

  property :doi, predicate: ::RDF::Vocab::Identifiers.doi, multiple: false do |index|
    index.as :stored_serachable
  end

  property :issn, predicate: ::RDF::Vocab::Identifiers.issn do |index|
    index.as :stored_serachable
  end

  property :isbn, predicate: ::RDF::Vocab::Identifiers.isbn do |index|
    index.as :stored_serachable
  end

  property :place_of_publication, predicate: ::RDF::URI('http://id.loc.gov/vocabulary/relators/pup') do |index|
    index.as :stored_serachable
  end

  property :journal_title, predicate: ::RDF::URI('http://rdaregistry.info/Elements/w/containedIn.en'),
           multiple: false do |index|
    index.as :stored_serachable
  end

  property :journal_volume, predicate: ::RDF::Vocab::BIBO.volume, multiple: false do |index|
    index.as :stored_serachable
  end

  property :journal_issue, predicate: ::RDF::Vocab::BIBO.issue, multiple: false do |index|
    index.as :stored_serachable
  end

  property :start_page, predicate: ::RDF::Vocab::SCHEMA.pageStart, multiple: false do |index|
    index.as :stored_serachable
  end

  property :end_page, predicate: ::RDF::Vocab::SCHEMA.pageEnd, multiple: false do |index|
    index.as :stored_serachable
  end

  property :url, predicate: ::RDF::Vocab::SCHEMA.url do |index|
    index.as :stored_serachable
  end

  property :digital_collection, predicate: ::RDF::URI('http://pcdm.org/models#memberOf') do |index|
    index.as :stored_serachable
  end


  # This must be included at the end, because it finalizes the metadata
  # schema (by adding accepts_nested_attributes)
  include ::Hyrax::BasicMetadata
end
