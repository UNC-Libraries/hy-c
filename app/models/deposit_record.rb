class DepositRecord < ActiveFedora::Base
  has_many :fedora_only_files, predicate: ActiveFedora::RDF::Fcrepo::RelsExt.hasMember

  # OAI_DC info
  property :title, predicate: ::RDF::Vocab::DC.title, multiple: false
  property :identifier, predicate: ::RDF::Vocab::DC.identifier, multiple: false
  # RDF description
  property :deposit_method, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#depositMethod'), multiple: false
  property :deposit_package_subtype, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#depositPackageSubtype'), multiple: false
  property :deposit_package_type, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#depositPackageType'), multiple: false
  property :deposited_by, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#depositedBy'), multiple: false
  # files
  property :manifest, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#depositManifest')
  property :premis, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#premis')
end
