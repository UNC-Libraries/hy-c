class FedoraOnlyFile < ActiveFedora::Base
  has_subresource 'file'

  belongs_to :deposit_record, predicate: ActiveFedora::RDF::Fcrepo::RelsExt.isPartOf

  property :title, predicate: ::RDF::Vocab::DC.title, multiple: false
  property :identifier, predicate: ::RDF::Vocab::DC.identifier, multiple: false
  property :date_created, predicate: ::RDF::Vocab::DC.created, multiple: false
  property :mime_type, predicate: ::RDF::Vocab::EBUCore.hasMimeType, multiple: false
end
