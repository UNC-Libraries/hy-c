# frozen_string_literal: true
require 'active_triples'

class Person < ActiveTriples::Resource
  include ActiveTriples::RDFSource
  configure type: RDF::Vocab::FOAF.Person

  property :name, predicate: RDF::Vocab::FOAF.name
  property :affiliation, predicate: "http://vivoweb.org/ontology/core#School"
  property :netid, predicate: "http://open.vocab.org/terms/accountIdentifier"

  def to_s
    "#{name.first}, #{affiliation.first} (#{netid.first})"
  end

  # We need to convert the URI on initialize so that
  # ActiveTriples can create a 'hash URI' for this
  # resource.  This is necessary so that we can edit
  # nested people within the ETD edit form.
  # (Without the hash URI, we wouldn't be able to edit
  # the person in the same sparql query as the
  # ETD.)
  # This code was taken from an example spec in the
  # active-fedora gem:
  # spec/integration/nested_hash_resources_spec.rb
  def initialize(uri, parent)
    if uri.try(:node?)
      uri = RDF::URI("#nested_#{uri.to_s.gsub('_:', '')}")
    elsif uri.start_with?("#")
      uri = RDF::URI(uri)
    end
    super
  end

  def last_name
    name.first.split(", ").first
  end

  def first_name
    name.first.split(", ").last
  end
end
