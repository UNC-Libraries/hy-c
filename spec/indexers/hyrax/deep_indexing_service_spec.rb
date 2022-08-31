# frozen_string_literal: true
require 'rails_helper'
# Load the override being tested
require Rails.root.join('app/overrides/indexers/hyrax/deep_indexing_service_override.rb')

RSpec.describe Hyrax::DeepIndexingService, type: :indexer do
  let(:work) { General.new(title: ['new general work']) }
  let(:service) { described_class.new(work) }
  subject(:solr_document) { service.generate_solr_document }
  let(:mail_sent) { GeonamesMailer.send_mail(error) }
  let(:error) {  Exception.new('bad geonames request') }
  let(:geonames_response) {
    <<RDFXML.strip_heredoc
      <?xml version="1.0" encoding="UTF-8" standalone="no"?>
          <rdf:RDF xmlns:foaf="http://xmlns.com/foaf/0.1/" xmlns:gn="http://www.geonames.org/ontology#" xmlns:owl="http://www.w3.org/2002/07/owl#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#">
          <gn:Feature rdf:about="http://sws.geonames.org/4460162/">
          <gn:name>Chapel Hill</gn:name>
          </gn:Feature>
          </rdf:RDF>
RDFXML
  }

  describe 'with a remote resource (based near)' do
    context 'with a successful call to geonames' do
      before do
        stub_request(:any, "http://api.geonames.org/getJSON?geonameId=4460162&username=#{ENV['GEONAMES_USER']}")
          .to_return(status: 200, body: { asciiName: 'Chapel Hill',
                                                 countryName: 'United States',
                                                 adminName1: 'North Carolina' }.to_json,
                            headers: { 'Content-Type' => 'application/json' })
        work.based_near_attributes = [{ id: 'http://sws.geonames.org/4460162/' }]
        stub_request(:get, 'http://sws.geonames.org/4460162/')
          .to_return(status: 200, body: geonames_response,
                     headers: { 'Content-Type' => 'application/rdf+xml;charset=UTF-8' })
      end

      it 'indexes id and label' do
        expect(solr_document.fetch('based_near_sim')).to eq ['http://sws.geonames.org/4460162/']
        expect(solr_document.fetch('based_near_label_sim')).to eq ['Chapel Hill, North Carolina, United States']
      end
    end

    context 'with an unsuccessful call to geonames' do

      before do
        allow(GeonamesMailer).to receive(:send_mail).and_return(mail_sent)

        stub_request(:get, "http://api.geonames.org/getJSON?geonameId=4460162&username=#{ENV['GEONAMES_USER']}")
          .to_return(status: 200, body: '', headers: {})
        work.based_near_attributes = [{ id: 'http://sws.geonames.org/4460162BadId/' }]
        stub_request(:get, 'http://sws.geonames.org/4460162BadId/')
          .to_return(status: 200, body: '', headers: { 'Content-Type' => 'application/rdf+xml;charset=UTF-8' })
      end

      it 'indexes id and label' do
        expect(solr_document).not_to have_key('based_near_label_sim')
        expect(solr_document).to have_key('based_near_sim')
        expect(solr_document.fetch('based_near_sim')).to eq ['http://sws.geonames.org/4460162BadId/']
      end

      it 'sends an email to administrators' do
        expect (GeonamesMailer.send_mail(error)).to have_received(mail_sent).with(any_args).at_least(:once)
      end
    end
  end
end
