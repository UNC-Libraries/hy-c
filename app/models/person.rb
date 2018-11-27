class Person < ActiveTriples::Resource

  property :name, predicate: ::RDF::Vocab::MODS.name
  property :orcid, predicate: ::RDF::Vocab::Identifiers.orcid
  property :affiliation, predicate: ::RDF::Vocab::SCHEMA.affiliation
  property :other_affiliation, predicate: ::RDF::Vocab::EBUCore.hasAffiliation

  def initialize(uri=RDF::Node.new, parent=nil)
    if uri.try(:node?)
      uri = RDF::URI("#nested_person#{uri.to_s.gsub('_:', '')}")
    elsif uri.start_with?("#")
      uri = RDF::URI(uri)
    end
    super
  end

  def final_parent
    parent
  end

  def new_record?
    id.start_with?("#")
  end

  def _destroy
    false
  end
end
