# frozen_string_literal: true
module HycGeonameHelper
  CHAPEL_HILL_RESP = <<RDFXML.strip_heredoc
    <?xml version="1.0" encoding="UTF-8" standalone="no"?>
        <rdf:RDF xmlns:foaf="http://xmlns.com/foaf/0.1/" xmlns:gn="http://www.geonames.org/ontology#" xmlns:owl="http://www.w3.org/2002/07/owl#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#">
        <gn:Feature rdf:about="http://sws.geonames.org/4460162/">
        <gn:name>Chapel Hill</gn:name>
        </gn:Feature>
        </rdf:RDF>
RDFXML

  def stub_geo_request
    stub_request(:get, 'http://sws.geonames.org/4460162/').
      to_return(status: 200, body: CHAPEL_HILL_RESP, headers: { 'Content-Type' => 'application/rdf+xml;charset=UTF-8' })

    stub_request(:any, /http:\/\/www\.geonames\.org\/getJSON\?geonameId=4460162&username=.*/).
      to_return(status: 200, body: { name: 'Chapel Hill',
                                     countryName: 'United States',
                                     adminName1: 'North Carolina' }.to_json,
                headers: { 'Content-Type' => 'application/json' })
  end
end
