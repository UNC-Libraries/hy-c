class DepositRecord < ActiveFedora::Base
  has_many :fedora_only_files, predicate: ActiveFedora::RDF::Fcrepo::RelsExt.hasMember

  # OAI_DC info
  property :title, predicate: ::RDF::Vocab::DC.title, multiple: false
  property :identifier, predicate: ::RDF::Vocab::DC.identifier, multiple: false
  # audit trail info
  property :audit_process, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#auditProcess'), multiple: false
  property :audit_action, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#auditAction'), multiple: false
  property :audit_component_id, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#auditComponentID'), multiple: false
  property :audit_responsibility, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#auditResponsibility'), multiple: false
  property :audit_date, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#auditDate'), multiple: false
  property :audit_justification, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#auditJustification'), multiple: false
  # RDF description
  property :deposit_method, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#depositMethod'), multiple: false
  property :deposit_package_subtype, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#depositPackageSubtype'), multiple: false
  property :deposit_package_type, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#depositPackageType'), multiple: false
  property :deposited_by, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#depositedBy'), multiple: false
  # files
  property :manifest, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#depositManifest')
  property :premis, predicate: ::RDF::URI('http://cdr.unc.edu/definitions/model#premis')
end
