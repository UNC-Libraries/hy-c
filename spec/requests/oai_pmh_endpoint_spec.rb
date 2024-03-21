# frozen_string_literal: true
require 'rails_helper'
require Rails.root.join('spec/support/oai_sample_solr_documents.rb')

RSpec.describe 'OAI-PMH catalog endpoint' do
  let(:repo_name) { 'Carolina Digital Repository' }
  let(:format) { 'oai_dc' }
  let(:limit) { 10 }
  let(:provider_config) { { repository_name: repo_name } }
  let(:document_config) { { limit: limit } }
  let(:oai_config) { { provider: provider_config, document: document_config } }
  let(:timestamps) do
    solrRecords['response']['docs'].map do |doc|
      Time.parse(doc['timestamp']).utc.iso8601
    end.sort!
  end
  let(:solrRecords) do
    ActiveFedora::SolrService.get('has_model_ssim:(Dissertation OR Article OR MastersPaper OR HonorsThesis OR Journal OR DataSet OR Multimed OR ScholarlyWork OR General OR Artwork) AND visibility_ssi:open', rows: 100)
  end
  before(:all) do
    solr = Blacklight.default_index.connection
    solr.delete_by_query('*:*')
    solr.commit
    solr.add([SLEEPY_HOLLOW, MYSTERIOUS_AFFAIR, BEOWULF, LEVIATHAN, PEASANTRY, GREAT_EXPECTATIONS, ILIAD, MISERABLES,
              MOBY_DICK, WAR_AND_PEACE, JANE_EYRE, SHERLOCK_HOLMES, PRIDE_AND_PREJUDICE, ALICE_IN_WONDERLAND, UDEKURABE, GRIMM_FAIRY_TALES,
              TOM_SAWYER, BEN_FRANKLIN, TIME_MACHINE, HUCK_FINN, COMMON_SENSE, BEING_EARNEST, SCARLET_LETTER, EMMA,
              WUTHERING_HEIGHTS, DRACULA, PETER_PAN, DOKO_E, TALE_OF_TWO_CITIES, FRANKENSTEIN])
    solr.commit
  end

  before do
    CatalogController.configure_blacklight do |config|
      config.oai = oai_config
    end
  end

  describe 'root page' do
    it 'displays an error message about missing verb' do
      get oai_catalog_path
      expect(response.body).to include('not a legal OAI-PMH verb')
    end
  end

  describe 'Identify verb' do
    scenario 'displays repository information' do
      get oai_catalog_path(verb: 'Identify')
      expect(response.body).to include(repo_name)
    end

    context 'as a POST request' do
      scenario 'displays repository information' do
        post oai_catalog_path(verb: 'Identify')
        expect(response.body).to include(repo_name)
      end
    end
  end

  describe 'ListRecords verb', :vcr do
    scenario 'displays a limited list of records' do
      get oai_catalog_path(verb: 'ListRecords', metadataPrefix: format)
      records = xpath '//xmlns:record'

      expect(records.count).to eq limit
    end

    context 'when number of records exceeds document limit' do
      let(:document_config) { { limit: 25 } }

      scenario 'a resumption token is provided' do
        params = { verb: 'ListRecords', metadataPrefix: format }
        expected_token = "oai_dc.f(#{timestamps.first}).u(#{timestamps.last}).t(#{timestamps.count}):25"
        get oai_catalog_path(params)
        token = xpath '//xmlns:resumptionToken'
        records = xpath '//xmlns:record'

        expect(records.count).to be 25
        expect(token.text).to eq expected_token
      end

      scenario 'a resumption token displays the next page of records' do
        # This test checks the last page of records instead of the second
        page = (timestamps.count / 25).floor * 25
        params = { verb: 'ListRecords',
                   resumptionToken: "oai_dc.f(#{timestamps.first}).u(#{timestamps.last}).t(#{timestamps.count}):#{page}" }

        get oai_catalog_path(params)
        records = xpath '//xmlns:record'

        expect(records.count).to eq(timestamps.count % 25)
      end

      scenario 'the last page of records provides an empty resumption token' do
        params = { verb: 'ListRecords',
                   resumptionToken: "oai_dc.f(#{timestamps.first}).u(#{timestamps.last}).t(#{timestamps.count}):25" }

        get oai_catalog_path(params)
        token = xpath '//xmlns:resumptionToken'

        expect(token.count).to be 1
        expect(token.text).to be_empty
      end

      scenario 'a resumption token is provided when a "from" parameter has a date value' do
        params = { verb: 'ListRecords', metadataPrefix: format, from: '2010-01-01' }
        expected_token = "oai_dc.f(2010-01-01T00:00:00Z).u(2021-11-23T00:00:00Z).t(#{timestamps.count}):25"
        get oai_catalog_path(params)
        token = xpath '//xmlns:resumptionToken'
        records = xpath '//xmlns:record'

        expect(records.count).to be 25
        expect(token.text).to eq expected_token
      end
    end

    context 'with a set' do
      let(:document_config) { { set_model: CdrListSet, set_fields: [{ label: 'language', solr_field: 'language_label_tesim' }] } }

      scenario 'only records from the set are returned' do
        params = { verb: 'ListRecords', metadataPrefix: format, set: 'language:Japanese' }

        get oai_catalog_path(params)
        records = xpath '//xmlns:record'

        expect(records.count).to be 2
      end
    end

    context 'with a from date' do
      scenario 'only records with a timestamp after the date are shown' do
        params = { verb: 'ListRecords', metadataPrefix: format,
                   from: timestamps[timestamps.count - 2] }

        get oai_catalog_path(params)
        records = xpath '//xmlns:record'
        expect(records.count).to be 2
        expect(response.body).to include(timestamps[timestamps.count - 1])
        expect(response.body).to include(timestamps[timestamps.count - 2])
        expect(response.body).not_to include(timestamps[timestamps.count - 3])
      end

      context 'and an until date' do
        scenario 'shows records between the dates' do
          params = { verb: 'ListRecords', metadataPrefix: format,
                     from: timestamps[3],
                     until: timestamps[8] }

          get oai_catalog_path(params)
          records = xpath '//xmlns:record'

          expect(records.count).to be 6
          expect(response.body).to include(timestamps[5])
          # Should only include the first 10 items as per the limit
          expect(response.body).not_to include(timestamps[10])
          expect(response.body).not_to include(timestamps[15])
        end
      end
    end

    context 'with an until date' do
      scenario 'only records with a timestamp before the date are shown' do
        params = { verb: 'ListRecords', metadataPrefix: format, until: timestamps[0] }

        get oai_catalog_path(params)
        records = xpath '//xmlns:record'

        expect(records.count).to be 1
        expect(response.body).to include(timestamps[0])
        expect(response.body).not_to include(timestamps[1])
      end
    end
  end

  describe 'GetRecord verb', :vcr do
    let(:solrRecords) { ActiveFedora::SolrService.get('has_model_ssim:Article', rows: 50) }
    let(:oai_identifier) { solrRecords['response']['docs'][0]['id'] }

    let(:params) { { verb: 'GetRecord', metadataPrefix: format, identifier: identifier } }
    let(:identifier) { "oai:localhost:#{oai_identifier}" }

    scenario 'displays a single record' do
      get oai_catalog_path(params)
      records = xpath '//xmlns:record'

      expect(records.count).to be 1
      expect(response.body).to include(identifier)
    end

    # Not currently implemented in official gem
    # context 'with an invalid identifier' do
    #   let(:identifier) { ':not_a_valid_id' }
    #
    #   it 'returns an error response' do
    #     get oai_catalog_path(params)
    #     expect(response.body).to include('idDoesNotExist')
    #   end
    # end
  end

  describe 'ListSets verb' do
    context 'without set configuration' do
      scenario 'shows that no sets exist' do
        get oai_catalog_path(verb: 'ListSets')
        expect(response.body).to include('This repository does not support sets.')
      end
    end

    context 'with set configuration', :vcr do
      let(:document_config) { { set_model: CdrListSet, set_fields: [{ label: 'language', solr_field: 'language_label_tesim' }] } }

      scenario 'shows all sets' do
        get oai_catalog_path(verb: 'ListSets')
        sets = xpath '//xmlns:set'
        expect(sets.count).to be 2 # There are currently sample documents in English and Japanese
      end

      scenario 'shows the correct verb' do
        get oai_catalog_path(verb: 'ListSets')
        expect(response.body).to include('request verb="ListSets"')
      end

      context 'where sets include descriptions' do
        let(:document_config) { { set_model: CdrListSet, set_fields: [{ label: 'admin set', solr_field: 'admin_set_tesim' }] } }

        scenario 'shows the set description object' do
          get oai_catalog_path(verb: 'ListSets')
          descriptions = xpath '//xmlns:set/xmlns:setDescription/oai_dc:dc/dc:description',
                               'xmlns' => 'http://www.openarchives.org/OAI/2.0/',
                               'dc' => 'http://purl.org/dc/elements/1.1/',
                               'oai_dc' => 'http://www.openarchives.org/OAI/2.0/oai_dc/'
          expect(descriptions.count).to be > 1
          expect(descriptions.text).to include('This set includes works in the default admin set.')
        end
      end
    end
  end

  describe 'ListMetadataFormats verb' do
    scenario 'lists the oai_dc format' do
      get oai_catalog_path(verb: 'ListMetadataFormats')
      expect(response.body).to include("<metadataPrefix>#{format}</metadataPrefix>")
    end
  end

  describe 'ListIdentifiers verb' do
    let(:solrRecords) { ActiveFedora::SolrService.get('has_model_ssim:Article', rows: 50, sort: 'timestamp asc') }
    # The limit is currently 10, so we should expect to get the first 10 items
    let(:oai_identifier1) { solrRecords['response']['docs'][0]['id'] }
    let(:oai_identifier2) { solrRecords['response']['docs'][9]['id'] }

    let(:expected_ids) { %W(oai:localhost:#{oai_identifier1} oai:localhost:#{oai_identifier2}) }

    scenario 'lists identifiers for works' do
      get oai_catalog_path(verb: 'ListIdentifiers', metadataPrefix: format)
      expect(response.body).to include(*expected_ids)
    end
  end

  def xpath(str, opts = nil)
    Nokogiri::XML(response.body).xpath(str, opts)
  end
end
