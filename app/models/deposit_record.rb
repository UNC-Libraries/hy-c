# Carried over from Box-C
# see https://github.com/UNC-Libraries/box-c/blob/b89e7b55a1f8a38332233674090de0f838838d4f/model-api/src/main/java/edu/unc/lib/boxc/model/api/rdf/Cdr.java#L51-L67
# for description source
class DepositRecord < ActiveFedora::Base
  has_many :fedora_only_files, predicate: ActiveFedora::RDF::Fcrepo::RelsExt.hasMember

  # OAI_DC info
  property :title, predicate: ::RDF::Vocab::DC.title, multiple: false
  # RDF description
  # Method by which this deposit was submitted, such as "sword" or "CDR web form"
  property :deposit_method, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#depositMethod'), multiple: false
  # Subclassification of the packaging type for this deposit, such as a METS profile.
  property :deposit_package_subtype, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#depositPackageSubtype'), multiple: false
  # URI representing the type of packaging used for the original deposit represented by this record, such as CDR METS or BagIt.
  property :deposit_package_type, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#depositPackageType'), multiple: false
  property :deposited_by, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#depositedBy'), multiple: false
  # files
  property :manifest, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#depositManifest')
  property :premis, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#premis')
end
